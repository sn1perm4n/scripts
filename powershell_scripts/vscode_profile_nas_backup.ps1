# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the VSCode User profile folder to a Linux-based NAS

# Robocopy exit code list:
# Exit Code Meaning
# 0			No files copied (no failures)
# 1			One or more files copied successfully (no failures)
# 2			Extra files or directories detected (deleted if /MIR is used)
# 3			Files copied and extra files/directories deleted (1 + 2)
# 4–7		Success with minor issues (mismatched files, skipped files, retryable errors)
# 8+		Failure — serious errors (network issue, permissions, etc.)

# NOTE: Exit codes 0–7 are generally considered successful for backup validation

$Source = "$env:APPDATA\Code\User"
$Destination = "\\NAS\PATH\TO\VSCODE_BACKUP_DIRECTORY"  # Change this to your NAS VSCode backup directory
$nasHost = "NAS_HOSTNAME"  # Change this to your NAS hostname

# Quick NAS availability check
Write-Host "`nChecking NAS availability ($nasHost)..." -ForegroundColor Cyan
if (-not (Test-Connection -ComputerName $nasHost -Count 1 -Quiet)) {
	Write-Host ""
	Write-Error "Backup aborted: $nasHost is not reachable."
	exit 1
}
Write-Host "$nasHost is reachable." -ForegroundColor Green

# Detect if VSCode is running and close it if y/Y is pressed (otherwise abort)
$vscodeProcess = Get-Process -Name "Code" -ErrorAction SilentlyContinue
if ($vscodeProcess) {
	$response = Read-Host "`nVSCode is currently running. Close VSCode now? (Y/N)"
	if ($response -match '^[Yy]$') {
		Write-Host "`nStopping VSCode..." -ForegroundColor Cyan
		Stop-Process -Name "Code" -Force
		Start-Sleep -Seconds 2
	}
	else {
		Write-Host ""
		Write-Error "Backup aborted: Please re-run the script and select 'Y' to close VSCode, or close VSCode manually before running again."
		exit 1
	}
}

# Verify source exists
if (-not (Test-Path $Source)) {
	Write-Host ""
	Write-Error "VSCode profile path not found: $Source"
	exit 1
}

# Build Robocopy arguments
# NOTE: There is no need to delete the existing backup folder from the destination folder before starting the backup
# The /MIR (mirror) flag in Robocopy ensures the backup folder always matches the source profile exactly — it copies new/updated files and removes any files that no longer exist in the source
# This safely maintains a single up-to-date backup at all times
$robocopyArgs = @(
	$Source,
	$Destination,
	"/MIR",
	"/FFT",
	"/R:1",
	"/W:1"
)

# Execute Robocopy
Write-Host "`nStarting VSCode profile backup..." -ForegroundColor Cyan
$robocopyOutput = robocopy @robocopyArgs
$exitCode = $LASTEXITCODE
Write-Host ($robocopyOutput -join "`n").TrimEnd()
if ($exitCode -le 3) {
	Write-Host "`nVSCode profile backup completed successfully (Robocopy exit code: $exitCode)." -ForegroundColor Green
	exit 0
}
else {
	Write-Host ""
	Write-Warning "VSCode profile backup completed with errors (Robocopy exit code: $exitCode)."
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.