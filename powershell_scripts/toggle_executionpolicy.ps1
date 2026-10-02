# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script reports or changes PowerShell's ExecutionPolicy on local and remote machines

# NOTE: This script requires elevation for every run via #Requires -RunAsAdministrator, consistent with toggle_ps-remoting.ps1 and other scripts that modify system-level configuration

# NOTE2: Local and remote targeting (-Hostname, -HostFile, -Credential, defaulting to the local machine when neither is given) mirrors toggle_ps-remoting.ps1 exactly, including using CIM over DCOM for remote targets so this works even if PS-Remoting itself isn't enabled yet on the target

# NOTE3: Remote changes are made by writing directly to the registry via the StdRegProv CIM class (SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell, value name ExecutionPolicy), which is the same location Set-ExecutionPolicy itself writes to locally for the LocalMachine and CurrentUser scopes

# NOTE4: -Scope Process only exists in the memory of a single running PowerShell process and is never written to the registry, so it cannot be queried or set on a remote target; a remote target combined with -Scope Process is skipped with a warning rather than attempted

# NOTE5: Setting -Policy Undefined does not write the literal string "Undefined" - it removes the registry value entirely (matching Set-ExecutionPolicy's own local behavior), so that scope falls through to whatever the next scope in the precedence order resolves to

# NOTE6: Remote -Scope CurrentUser depends on StdRegProv resolving HKEY_CURRENT_USER to the authenticated user's profile on the target, which is less reliable than LocalMachine remotely since it depends on that user's profile being loaded; -Scope LocalMachine is the more dependable choice for remote targets

# NOTE7: If -Policy is omitted (and -Preview is not used), a numbered menu of the six valid policy values is shown so one can be chosen interactively; the selected value then goes through the same apply logic as if -Policy had been passed directly

# NOTE8: -Preview requires -Policy, since it reports what a specific change would do (current vs. proposed) rather than just current status; nothing is written to the registry or via Set-ExecutionPolicy in -Preview mode

# NOTE9: A failure on one target is logged as a warning and does not stop the remaining targets in -HostFile from being processed

# Optional flags:
#     -Credential:                                 Prompt for alternate credentials to use against remote targets (input is masked); omit to use the current user's context
#     -HostFile <PATH>:                             Path to a text file listing one remote hostname per line (mutually exclusive with -Hostname)
#     -Hostname <PATH>:                             A single remote hostname to target (mutually exclusive with -HostFile)
#     -NoConsoleOutput:                             Suppress console output (requires -Policy)
#     -Policy <PATH>:                               The new ExecutionPolicy to apply - one of Restricted, AllSigned, RemoteSigned, Unrestricted, Bypass, or Undefined; omit for an interactive menu
#     -Preview:                                     Report the current and proposed ExecutionPolicy for each target without making changes (requires -Policy)
#     -SaveResults <PATH>:                          Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Scope <Process|CurrentUser|LocalMachine>:    Which scope to target (default: LocalMachine)
#     -Help / -?:                                   Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Credential,
	[string]$HostFile,
	[string]$Hostname,
	[switch]$NoConsoleOutput,
	[ValidateSet('Restricted', 'AllSigned', 'RemoteSigned', 'Unrestricted', 'Bypass', 'Undefined')]
	[string]$Policy,
	[switch]$Preview,
	[string]$SaveResults,
	[ValidateSet('Process', 'CurrentUser', 'LocalMachine')]
	[string]$Scope = 'LocalMachine',
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Credential] [-HostFile <PATH>] [-Hostname <PATH>] [-NoConsoleOutput] [-Policy <PATH>] [-Preview] [-SaveResults <PATH>] [-Scope <Process|CurrentUser|LocalMachine>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Credential                                 Prompt for alternate credentials to use against remote targets (input is masked); omit to use the current user's context" -ForegroundColor Cyan
	Write-Host "  -HostFile <PATH>                             Path to a text file listing one remote hostname per line (mutually exclusive with -Hostname)" -ForegroundColor Cyan
	Write-Host "  -Hostname <PATH>                             A single remote hostname to target (mutually exclusive with -HostFile)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput                             Suppress console output (requires -Policy)" -ForegroundColor Cyan
	Write-Host "  -Policy <PATH>                               The new ExecutionPolicy to apply - one of Restricted, AllSigned, RemoteSigned, Unrestricted, Bypass, or Undefined; omit for an interactive menu" -ForegroundColor Cyan
	Write-Host "  -Preview                                     Report the current and proposed ExecutionPolicy for each target without making changes (requires -Policy)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>                          Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Scope <Process|CurrentUser|LocalMachine>    Which scope to target (default: LocalMachine)" -ForegroundColor Cyan
	Write-Host "  -Help                                        Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -Preview requires -Policy, since it reports what a specific change would do rather than just current status
if ($Preview -and -not $Policy) {
	Write-Host ""
	Write-Error "-Preview requires -Policy."
	exit 1
}

# -Hostname and -HostFile are mutually exclusive, since they're two different ways of specifying the same thing
if ($Hostname -and $HostFile) {
	Write-Host ""
	Write-Error "-Hostname and -HostFile are mutually exclusive."
	exit 1
}

# -HostFile requires the file to already exist, since it's read from rather than written to
if ($HostFile -and -not (Test-Path $HostFile)) {
	Write-Host ""
	Write-Error "-HostFile not found: '$HostFile'"
	exit 1
}

# -NoConsoleOutput requires -Policy, since without it the script falls into interactive mode, which needs the console
if ($NoConsoleOutput -and -not $Policy) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -Policy."
	exit 1
}

# -NoConsoleOutput also requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Validate the save path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Write the hostname as a header line the first time -SaveResults is created, so a fleet of per-machine files can be identified at a glance
if ($SaveResults -and -not (Test-Path $SaveResults)) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
	}
	catch {
		Write-Host ""
		Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
	}
}

# Build the list of targets: an explicit single host, a file of hosts, or the local machine by default
if ($Hostname) {
	$targets = @($Hostname)
}
elseif ($HostFile) {
	$targets = @(Get-Content -Path $HostFile | Where-Object { $_.Trim() -ne '' })
}
else {
	$targets = @($env:COMPUTERNAME)
}

# Prompt for alternate credentials if requested; Get-Credential always masks the password input
$credParam = @{}
if ($Credential) {
	$remoteCredential = Get-Credential -Message "Enter credentials for remote ExecutionPolicy management"
	if (-not $remoteCredential) {
		Write-Host ""
		Write-Error "No credentials were entered."
		exit 1
	}
	$credParam = @{ Credential = $remoteCredential }
}

# If -Policy was not supplied and this isn't a -Preview run, prompt with a numbered menu instead
if (-not $Policy) {
	$validPolicies = @('Restricted', 'AllSigned', 'RemoteSigned', 'Unrestricted', 'Bypass', 'Undefined')

	Write-Host "Select a new ExecutionPolicy:`n" -ForegroundColor Cyan
	for ($i = 0; $i -lt $validPolicies.Count; $i++) {
		Write-Host "$($i + 1). $($validPolicies[$i])"
	}

	Write-Host ""
	$selection = Read-Host "Enter a number, or press Enter to cancel"

	if (-not $selection) {
		Write-Host ""
		Write-Warning "Cancelled - no changes were made."
		exit 0
	}

	$parsedNumber = 0
	if (-not [int]::TryParse($selection, [ref]$parsedNumber) -or $parsedNumber -lt 1 -or $parsedNumber -gt $validPolicies.Count) {
		Write-Host ""
		Write-Error "'$selection' is not a valid selection."
		exit 1
	}

	$Policy = $validPolicies[$parsedNumber - 1]
}

# Registry location Set-ExecutionPolicy itself uses locally for the LocalMachine and CurrentUser scopes
$regSubKeyPath = 'SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'
$regValueName = 'ExecutionPolicy'
$hiveMap = @{ LocalMachine = [uint32]2147483650; CurrentUser = [uint32]2147483649 }

$resultLines = @()

foreach ($target in $targets) {
	$isLocal = ($target -eq $env:COMPUTERNAME) -or ($target -eq 'localhost') -or ($target -eq '.')

	# -Scope Process only exists in a running process's own memory and cannot be reached remotely
	if ($Scope -eq 'Process' -and -not $isLocal) {
		Write-Host ""
		Write-Warning "Skipping '$target' - -Scope Process cannot be set or queried on a remote target."
		continue
	}

	try {
		if ($isLocal) {
			$currentPolicy = (Get-ExecutionPolicy -Scope $Scope).ToString()
		}
		else {
			$dcomSession = New-CimSession -ComputerName $target -SessionOption (New-CimSessionOption -Protocol Dcom) @credParam -ErrorAction Stop
			$getParam = @{
				CimSession = $dcomSession
				ClassName  = 'StdRegProv'
				Namespace  = 'root/default'
				MethodName = 'GetStringValue'
				Arguments  = @{ hDefKey = $hiveMap[$Scope]; sSubKeyName = $regSubKeyPath; sValueName = $regValueName }
			}
			$getResult = Invoke-CimMethod @getParam -ErrorAction Stop
			$currentPolicy = if ($getResult.sValue) { $getResult.sValue } else { 'Undefined' }
		}
	}
	catch {
		Write-Host ""
		Write-Warning "Could not read the current ExecutionPolicy on '$target': $($_.Exception.Message)"
		if ($dcomSession) { Remove-CimSession -CimSession $dcomSession }
		continue
	}

	if ($Preview) {
		$summaryLine = "$ScriptName`: [$target] [$Scope] Current = $currentPolicy, Proposed = $Policy"
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Cyan }
		$resultLines += $summaryLine
		if ($dcomSession) { Remove-CimSession -CimSession $dcomSession }
		continue
	}

	try {
		if ($isLocal) {
			Set-ExecutionPolicy -ExecutionPolicy $Policy -Scope $Scope -Force -ErrorAction SilentlyContinue -ErrorVariable setPolicyError

			# Verify the scope we actually targeted took the new value - this is the real measure of success, independent of any more-specific scope overriding the *effective* policy
			$verifiedPolicy = (Get-ExecutionPolicy -Scope $Scope).ToString()
			if ($verifiedPolicy -ne $Policy) {
				throw "Value did not take (now reads '$verifiedPolicy'). $($setPolicyError[0].Exception.Message)"
			}

			# A more specific scope (CurrentUser, UserPolicy, or MachinePolicy) can still override what was just set here -
			# the write above succeeded regardless, but new sessions may not actually use $Policy as their effective policy
			$effectivePolicy = (Get-ExecutionPolicy).ToString()
			if ($effectivePolicy -ne $Policy) {
				Write-Host ""
				Write-Warning "The $Scope scope was set to $Policy successfully, but a more specific scope is overriding it - the effective policy is currently $effectivePolicy. Run Get-ExecutionPolicy -List to see all scopes."
			}
		}
		else {
			if ($Policy -eq 'Undefined') {
				# Undefined removes the value entirely rather than writing the literal string "Undefined", matching Set-ExecutionPolicy's own local behavior
				$deleteParam = @{
					CimSession = $dcomSession
					ClassName  = 'StdRegProv'
					Namespace  = 'root/default'
					MethodName = 'DeleteValue'
					Arguments  = @{ hDefKey = $hiveMap[$Scope]; sSubKeyName = $regSubKeyPath; sValueName = $regValueName }
				}
				$writeResult = Invoke-CimMethod @deleteParam -ErrorAction Stop
				# ReturnValue 2 means the value didn't exist to begin with, which is already the desired end state
				if ($writeResult.ReturnValue -ne 0 -and $writeResult.ReturnValue -ne 2) {
					throw "DeleteValue returned code $($writeResult.ReturnValue)"
				}
			}
			else {
				$createParam = @{
					CimSession = $dcomSession
					ClassName  = 'StdRegProv'
					Namespace  = 'root/default'
					MethodName = 'CreateKey'
					Arguments  = @{ hDefKey = $hiveMap[$Scope]; sSubKeyName = $regSubKeyPath }
				}
				Invoke-CimMethod @createParam -ErrorAction Stop | Out-Null

				$setParam = @{
					CimSession = $dcomSession
					ClassName  = 'StdRegProv'
					Namespace  = 'root/default'
					MethodName = 'SetStringValue'
					Arguments  = @{ hDefKey = $hiveMap[$Scope]; sSubKeyName = $regSubKeyPath; sValueName = $regValueName; sValue = $Policy }
				}
				$writeResult = Invoke-CimMethod @setParam -ErrorAction Stop
				if ($writeResult.ReturnValue -ne 0) {
					throw "SetStringValue returned code $($writeResult.ReturnValue)"
				}
			}
			Remove-CimSession -CimSession $dcomSession
		}

		$summaryLine = "$ScriptName`: [$target] [$Scope] Changed from $currentPolicy to $Policy."
		if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }
		$resultLines += $summaryLine
	}
	catch {
		Write-Host ""
		Write-Warning "Could not set the ExecutionPolicy on '$target': $($_.Exception.Message)"
		if ($dcomSession) { Remove-CimSession -CimSession $dcomSession }
	}
}

if ($resultLines.Count -eq 0) {
	$resultLines += "$ScriptName`: [$env:COMPUTERNAME] No changes were made."
}

# Save results
if ($SaveResults) {
	try {
		$content = ($resultLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $content)
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.