# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script restarts or shuts down the local machine or one or more remote machines. If no hostname is specified, the local machine is targeted.

# NOTE: Remote operations require PowerShell remoting or WMI access to be enabled on the target machine. Run Enable-PSRemoting on the target or ensure WMI is accessible. Both hostnames and IP addresses are accepted.

# NOTE2: -Abort cancels a pending restart or shutdown previously triggered on the target(s). It is not used alongside -Restart or -Shutdown.

# NOTE3: -Parallel processes all hosts simultaneously. Without it, hosts are processed sequentially. -Parallel is only relevant when targeting multiple hosts.

# Optional flags:
#     -Abort: Cancel a pending restart or shutdown on the target(s)
#     -Credential: Prompt for credentials for remote operations (optional — use if your current session lacks sufficient rights on the target). Password input is hidden via a secure Windows credential dialog.
#     -Delay <N>: Seconds before the operation executes (default: 0)
#     -Force: Force close running applications without prompting
#     -HostFile <PATH>: Path to a text file containing one hostname per line
#     -Hostname <NAME> / -IP <ADDRESS>: Target hostname, IP address, or comma-separated list
#     -Parallel: Process all hosts simultaneously instead of sequentially
#     -Restart: Restart the target(s)
#     -SaveResults <PATH>: Save results to a text file
#     -Shutdown: Shut down the target(s)
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Abort,
	[switch]$Credential,
	[int]$Delay = 0,
	[switch]$Force,
	[string]$HostFile,
	[Alias("IP")]
	[string]$Hostname,
	[switch]$Parallel,
	[switch]$Restart,
	[string]$SaveResults,
	[switch]$Shutdown,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Abort] [-Credential] [-Delay <N>] [-Force] [-HostFile <PATH>] [-Hostname <NAME>] [-Parallel] [-Restart] [-SaveResults <PATH>] [-Shutdown] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Abort               Cancel a pending restart or shutdown on the target(s)" -ForegroundColor Cyan
	Write-Host "  -Credential          Prompt for credentials for remote operations (optional — use if your current session lacks sufficient rights on the target). Password input is hidden via a secure Windows credential dialog." -ForegroundColor Cyan
	Write-Host "  -Delay <N>           Seconds before the operation executes (default: 0)" -ForegroundColor Cyan
	Write-Host "  -Force               Force close running applications without prompting" -ForegroundColor Cyan
	Write-Host "  -HostFile <PATH>     Path to a text file containing one hostname per line" -ForegroundColor Cyan
	Write-Host "  -Hostname / -IP      Target hostname, IP address, or comma-separated list" -ForegroundColor Cyan
	Write-Host "  -Parallel            Process all hosts simultaneously instead of sequentially" -ForegroundColor Cyan
	Write-Host "  -Restart             Restart the target(s)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file" -ForegroundColor Cyan
	Write-Host "  -Shutdown            Shut down the target(s)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Validate flag combinations
if ($Restart -and $Shutdown) {
	Write-Host ""
	Write-Warning "-Restart and -Shutdown cannot be used together."
	exit 1
}

if ($Abort -and ($Restart -or $Shutdown)) {
	Write-Host ""
	Write-Warning "-Abort cannot be used with -Restart or -Shutdown. -Abort cancels a previously triggered operation."
	exit 1
}

if (-not $Restart -and -not $Shutdown -and -not $Abort) {
	Write-Host ""
	Write-Warning "No operation specified. Use -Restart, -Shutdown, or -Abort."
	exit 1
}

if ($Hostname -and $HostFile) {
	Write-Host ""
	Write-Warning "-Hostname and -HostFile cannot be used together."
	exit 1
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Validate -HostFile if specified
if ($HostFile) {
	if (-not (Test-Path $HostFile)) {
		Write-Host ""
		Write-Error "The host file does not exist: '$HostFile'"
		exit 1
	}
}

# Validate -Delay
if ($Delay -lt 0) {
	Write-Host ""
	Write-Warning "-Delay cannot be negative."
	exit 1
}

# Build host list
$hosts = @()
if ($Hostname) {
	$hosts = $Hostname -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}
elseif ($HostFile) {
	$hosts = Get-Content $HostFile | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Default to local machine if no hosts specified
$isLocal = $hosts.Count -eq 0
if ($isLocal) {
	$hosts = @($env:COMPUTERNAME)
}

if ($Parallel -and $hosts.Count -eq 1) {
	Write-Warning "-Parallel has no effect when targeting a single host."
}

# Prompt for credentials if -Credential is specified and targeting remote machines
$cred = $null
if ($Credential -and -not $isLocal) {
	$cred = Get-Credential -Message "Enter credentials for remote operation"
	if (-not $cred) {
		Write-Host ""
		Write-Warning "No credentials provided. Exiting."
		exit 1
	}
}

$OutputLines = @()
$successCount = 0
$failCount = 0

$operation = if ($Restart) { "Restart" }
elseif ($Shutdown) { "Shutdown" }
else { "Abort" }

Write-Host ""

$processHost = {
	param($targetHost, $op, $forceOp, $delayOp, $credOp, $isLocalOp)

	$result = [PSCustomObject]@{
		Host = $targetHost
		Success = $false
		Message = ""
	}

	try {
		$params = @{
			ComputerName = $targetHost
			Force = $forceOp
			Delay = $delayOp
			ErrorAction = "Stop"
		}

		if ($credOp -and -not $isLocalOp) {
			$params.Credential = $credOp
		}

		switch ($op) {
			"Restart" {
				Restart-Computer @params
				$result.Success = $true
				$result.Message = "Restart initiated successfully."
			}
			"Shutdown" {
				Stop-Computer @params
				$result.Success = $true
				$result.Message = "Shutdown initiated successfully."
			}
			"Abort" {
				if ($isLocalOp) {
					& shutdown.exe /a | Out-Null
				}
				else {
					Invoke-Command -ComputerName $targetHost -Credential $credOp -ScriptBlock { & shutdown.exe /a } -ErrorAction Stop
				}
				$result.Success = $true
				$result.Message = "Pending operation aborted successfully."
			}
		}
	}
	catch {
		$result.Success = $false
		$result.Message = $_.Exception.Message
	}

	return $result
}

if ($Parallel -and $hosts.Count -gt 1) {
	Write-Host "Processing $($hosts.Count) host(s) in parallel..." -ForegroundColor Cyan
	$jobs = @()
	foreach ($h in $hosts) {
		$jobs += Start-Job -ScriptBlock $processHost -ArgumentList $h, $operation, $Force, $Delay, $cred, $isLocal
	}
	$results = $jobs | Wait-Job | Receive-Job
	$jobs | Remove-Job
}
else {
	$results = @()
	foreach ($h in $hosts) {
		Write-Host "Processing: $h" -ForegroundColor Cyan
		$results += & $processHost $h $operation $Force $Delay $cred $isLocal
	}
}

foreach ($result in $results) {
	if ($result.Success) {
		Write-Host "$($result.Host): $($result.Message)" -ForegroundColor Green
		$OutputLines += "$($result.Host): $($result.Message)"
		$successCount++
	}
	else {
		Write-Host ""
		Write-Warning "$($result.Host): $($result.Message)"
		$OutputLines += "Warning: $($result.Host): $($result.Message)"
		$failCount++
	}
}

$summaryLine = "$ScriptName`: $operation completed — $successCount succeeded, $failCount failed."
Write-Host "`n$summaryLine" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
$OutputLines += $summaryLine

# Save results
if ($SaveResults) {
	try {
		while ($OutputLines.Count -gt 0 -and $OutputLines[-1] -eq '') {
			$OutputLines = $OutputLines[0..($OutputLines.Count - 2)]
		}
		$outputString = ($OutputLines -join "`n")
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.