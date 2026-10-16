# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script reports or changes the Windows 11 Start menu size (Automatic, Small, or Large)

# NOTE: Start menu size first appeared in builds 26100.9278 (24H2), 26200.9278 (25H2), and 26300.8553 (26H2), but it rolls out gradually, so a supported build may not show the setting yet; this script only writes the registry value and can't tell whether Windows has enabled the setting for this machine

# NOTE2: This script changes a per-user HKCU (HKEY_CURRENT_USER) setting, so it only works on the local machine. Remote targeting like toggle_ps-remoting.ps1 and toggle_executionpolicy.ps1 offer would resolve HKCU to the authenticating account's profile instead of the intended user's.

# NOTE3: The size is stored as a REG_DWORD named StartMenuSize at HKCU:\Software\Microsoft\Windows\CurrentVersion\Start: 0 = Automatic (default), 1 = Small, 2 = Large

# Optional flags:
#     -NoConsoleOutput:              Suppress console output (requires -Size and -SaveResults)
#     -Preview:                      Show the current and proposed Start menu size without making changes (requires -Size)
#     -SaveResults <PATH>:           Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Size <Automatic|Small|Large>: The new Start menu size to apply; omit for an interactive menu
#     -Help / -?:                    Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[ValidateSet('Automatic', 'Small', 'Large')]
	[string]$Size,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Size <Automatic|Small|Large>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput              Suppress console output (requires -Size and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview                      Show the current and proposed Start menu size without making changes (requires -Size)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>           Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Size <Automatic|Small|Large> The new Start menu size to apply; omit for an interactive menu" -ForegroundColor Cyan
	Write-Host "  -Help                         Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -Preview requires -Size, since it reports what a specific change would do rather than just current status
if ($Preview -and -not $Size) {
	Write-Host ""
	Write-Error "-Preview requires -Size."
	exit 1
}

# -NoConsoleOutput requires -Size, since without it the script falls into interactive mode, which needs the console
if ($NoConsoleOutput -and -not $Size) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -Size."
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

$resultLines = @()

# The base build number (and its update revision, UBR) is read from the registry, since [System.Environment]::OSVersion doesn't reliably include the revision
$ntKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build = [int]$ntKey.CurrentBuildNumber
$revision = [int]$ntKey.UBR

# Builds before 24H2 (build 26100) never have this setting, so there is nothing to do
if ($build -lt 26100) {
	$unsupportedLine = "$ScriptName`: [$env:COMPUTERNAME] The Start menu size setting requires Windows 11 24H2 (build 26100) or later; this machine is on build $build."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $unsupportedLine
	}
	$resultLines += $unsupportedLine

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

	exit 1
}

# First build revision documented to include the setting, per base build; an older revision only warns, since a build that has it can still be missing the setting during the gradual rollout
$minRevisions = @{ 26100 = 9278; 26200 = 9278; 26300 = 8553 }
if ($minRevisions.ContainsKey($build) -and $revision -lt $minRevisions[$build]) {
	$olderLine = "Build $build.$revision is older than the first build documented to include the Start menu size setting ($build.$($minRevisions[$build])), so the setting may not exist yet."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $olderLine
	}
	$resultLines += "$ScriptName`: [$env:COMPUTERNAME] $olderLine"
}

# If -Size was not supplied, prompt with a numbered menu instead
if (-not $Size) {
	$validSizes = @('Automatic', 'Small', 'Large')

	Write-Host "`nSelect a new Start menu size:`n" -ForegroundColor Cyan
	for ($i = 0; $i -lt $validSizes.Count; $i++) {
		Write-Host "$($i + 1). $($validSizes[$i])"
	}

	Write-Host ""
	$selection = Read-Host "Enter a number, or press Enter to cancel"

	if (-not $selection) {
		Write-Host ""
		Write-Warning "Cancelled - no changes were made."
		exit 0
	}

	$parsedNumber = 0
	if (-not [int]::TryParse($selection, [ref]$parsedNumber) -or $parsedNumber -lt 1 -or $parsedNumber -gt $validSizes.Count) {
		Write-Host ""
		Write-Error "'$selection' is not a valid selection."
		exit 1
	}

	$Size = $validSizes[$parsedNumber - 1]
}

$startKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
$sizeToValue = @{ Automatic = 0; Small = 1; Large = 2 }
$valueToSize = @{ 0 = 'Automatic'; 1 = 'Small'; 2 = 'Large' }

# An unset value means Automatic, which is the default
$currentValue = (Get-ItemProperty -Path $startKeyPath -Name 'StartMenuSize' -ErrorAction SilentlyContinue).StartMenuSize
if ($null -eq $currentValue) {
	$currentDisplay = 'Automatic (not set)'
}
elseif ($valueToSize.ContainsKey([int]$currentValue)) {
	$currentDisplay = $valueToSize[[int]$currentValue]
}
else {
	$currentDisplay = "Unknown ($currentValue)"
}

$targetValue = $sizeToValue[$Size]
$exitCode = 0

if ($Preview) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Current = $currentDisplay, Proposed = $Size"
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Cyan }
	$resultLines += $summaryLine
}
elseif ($null -ne $currentValue -and [int]$currentValue -eq $targetValue) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] The Start menu size is already set to $Size."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
	$resultLines += $summaryLine
}
else {
	try {
		if (-not (Test-Path $startKeyPath)) { New-Item -Path $startKeyPath -Force -ErrorAction Stop | Out-Null }
		Set-ItemProperty -Path $startKeyPath -Name 'StartMenuSize' -Type DWord -Value $targetValue -Force -ErrorAction Stop

		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Changed from $currentDisplay to $Size."
		if (-not $NoConsoleOutput) {
			Write-Host "`n$summaryLine" -ForegroundColor Green
			Write-Host "Open the Start menu to check; if it hasn't changed, restart File Explorer or sign out and back in." -ForegroundColor Green
		}
		$resultLines += $summaryLine
	}
	catch {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Could not set the Start menu size: $($_.Exception.Message)"
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $summaryLine
		}
		$resultLines += $summaryLine
		$exitCode = 1
	}
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

exit $exitCode

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.