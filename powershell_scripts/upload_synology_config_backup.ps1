# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uploads a Synology config backup file from a NAS to a remote server via SFTP using WinSCP, then deletes all old Synology config backup files from the remote server and the NAS
# Use Invoke-PS2EXE -InputFile "PATH\TO\Script.ps1" -OutputFile "PATH\TO\Script.exe" to turn this script into a .exe to hide the password

# NOTE: SFTP credentials are hardcoded in the script. Update HostName, UserName, Password, and SshHostKeyFingerprint before use.

# NOTE2: The WinSCP session log is saved alongside the Synology backup file as WinSCP.log when -Sftp is not used as a flag (SFTP is the core purpose of this script)

# Optional flags:
#     -Backup <PATH>: Override the default local backup source folder (%USERPROFILE%\Desktop)
#     -NoConsoleOutput: Suppress all console output (requires -SaveResults)
#     -Preview: Show what would happen without actually uploading or deleting anything
#     -SaveResults <PATH>: Save console output to a text file
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[string]$Backup,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup <PATH>] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup <PATH>       Override the default local backup source folder (%USERPROFILE%\Desktop)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress all console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would happen without actually uploading or deleting anything" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save console output to a text file" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Warn if -NoConsoleOutput is used without -SaveResults
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Warning "-NoConsoleOutput has no effect without -SaveResults. Output would be suppressed entirely."
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

# Validate -Backup path if specified
if ($Backup) {
	if (-not (Test-Path $Backup)) {
		Write-Host ""
		Write-Error "The directory for -Backup does not exist: '$Backup'"
		exit 1
	}
}

# Set local backup source folder
$localFolder = if ($Backup) { $Backup } else { "$env:USERPROFILE\Desktop" }
$logPath = Join-Path -Path $localFolder -ChildPath "WinSCP.log"

# SFTP settings (update before use)
$remoteFolder = "/mnt/path/to/remote/Synology Config Backup"
$sftpHost = "HOSTNAME"
$sftpUser = "USERNAME"
$sftpPassword = "PASSWORD"
$sftpFingerprint = "ssh-ed25519 256 44:29:e2:b6:ff:45:55:a8:f9:15:36:4a:40:8b:1a:86"

$OutputLines = @()

# Find the newest Synology_* file in the local folder
$localFile = Get-ChildItem -Path $localFolder -Filter "Synology_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $localFile) {
	if (-not $NoConsoleOutput) { Write-Error "No file found matching Synology_* in '$localFolder'" }
	$OutputLines += "Error: No file found matching Synology_* in '$localFolder'"
	if ($SaveResults) {
		$outputString = ($OutputLines -join "`n") + "`n"
		try { [System.IO.File]::AppendAllText($SaveResults, $outputString) } catch { $null = $_ }
	}
	exit 1
}

$remotePath = "$remoteFolder/$($localFile.Name)"

# Find old local files that would be deleted (all Synology_* except the newest)
$oldLocalFiles = Get-ChildItem -Path $localFolder -Filter "Synology_*" |
	Where-Object { $_.FullName -ne $localFile.FullName }

if ($Preview) {
	if (-not $NoConsoleOutput) { Write-Host "`nPreview mode — no changes will be made." -ForegroundColor Cyan }
	$OutputLines += "Preview mode — no changes will be made."
	if (-not $NoConsoleOutput) { Write-Host "`nWould upload: $($localFile.FullName)" -ForegroundColor Cyan }
	$OutputLines += "Would upload: $($localFile.FullName)"
	if (-not $NoConsoleOutput) { Write-Host "Would upload to: $remotePath" -ForegroundColor Cyan }
	$OutputLines += "Would upload to: $remotePath"
	if (-not $NoConsoleOutput) { Write-Host "`nWould delete all old Synology_* files from remote: $remoteFolder" -ForegroundColor Cyan }
	$OutputLines += "Would delete all old Synology_* files from remote: $remoteFolder"
	if ($oldLocalFiles) {
		if (-not $NoConsoleOutput) { Write-Host "`nWould delete old local file(s):" -ForegroundColor Cyan }
		$OutputLines += "Would delete old local file(s):"
		foreach ($f in $oldLocalFiles) {
			if (-not $NoConsoleOutput) { Write-Host "  $($f.FullName)" -ForegroundColor Cyan }
			$OutputLines += "  $($f.FullName)"
		}
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "`nNo old local Synology_* files found to delete." -ForegroundColor Cyan }
		$OutputLines += "No old local Synology_* files found to delete."
	}
	if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Preview completed successfully." -ForegroundColor Cyan }
	$OutputLines += "$ScriptName`: Preview completed successfully."
}
else {
	# Check WinSCP is installed
	$winScpDll = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
	if (-not (Test-Path $winScpDll)) {
		if (-not $NoConsoleOutput) { Write-Warning "WinSCP is not installed or WinSCPnet.dll was not found at: $winScpDll" }
		$OutputLines += "Warning: WinSCP is not installed or WinSCPnet.dll was not found at: $winScpDll"
		if (-not $NoConsoleOutput) { Write-Host "Please install WinSCP from https://winscp.net and re-run." -ForegroundColor Yellow }
		$OutputLines += "Please install WinSCP from https://winscp.net and re-run."
		if ($SaveResults) {
			$outputString = ($OutputLines -join "`n") + "`n"
			try { [System.IO.File]::AppendAllText($SaveResults, $outputString) } catch { $null = $_ }
		}
		exit 1
	}

	Add-Type -Path $winScpDll

	$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
		Protocol = [WinSCP.Protocol]::Sftp
		HostName = $sftpHost
		UserName = $sftpUser
		Password = $sftpPassword
		SshHostKeyFingerprint = $sftpFingerprint
	}

	$rawSettings = @{
		"Cipher" = "aes,blowfish,3des,chacha20,WARN,arcfour,des"
		"KEX" = "ecdh,dh-gex-sha1,dh-group14-sha1,dh-group1-sha1,rsa,WARN"
	}
	foreach ($key in $rawSettings.Keys) {
		$sessionOptions.AddRawSettings($key, $rawSettings[$key])
	}

	$session = New-Object WinSCP.Session
	$uploadSuccess = $false
	try {
		$session.SessionLogPath = $logPath
		$session.Open($sessionOptions)

		# Delete all old Synology_* files from remote
		try {
			if (-not $NoConsoleOutput) { Write-Host "`nDeleting old Synology_* files from remote: $remoteFolder" -ForegroundColor Yellow }
			$OutputLines += "Deleting old Synology_* files from remote: $remoteFolder"
			$session.RemoveFiles("$remoteFolder/Synology_*").Check()
			if (-not $NoConsoleOutput) { Write-Host "Old remote Synology_* files deleted successfully." -ForegroundColor Green }
			$OutputLines += "Old remote Synology_* files deleted successfully."
		}
		catch { $null = $_ }

		# Upload the new Synology backup config
		if (-not $NoConsoleOutput) { Write-Host "`nUploading: $($localFile.FullName)" -ForegroundColor Cyan }
		$OutputLines += "Uploading: $($localFile.FullName)"
		$transferResult = $session.PutFiles($localFile.FullName, $remotePath, $false)
		$transferResult.Check()
		if (-not $NoConsoleOutput) { Write-Host "Upload succeeded: $($transferResult.Transfers[0].FileName)" -ForegroundColor Green }
		$OutputLines += "Upload succeeded: $($transferResult.Transfers[0].FileName)"
		$uploadSuccess = $true
	}
	catch {
		if (-not $NoConsoleOutput) { Write-Warning "SFTP operation failed: $($_.Exception.Message)" }
		$OutputLines += "Warning: SFTP operation failed: $($_.Exception.Message)"
	}
	finally {
		$session.Dispose()
	}

	# Delete old local Synology_* files
	if ($oldLocalFiles) {
		try {
			if (-not $NoConsoleOutput) { Write-Host "`nDeleting old local Synology_* files..." -ForegroundColor Yellow }
			$OutputLines += "Deleting old local Synology_* files..."
			foreach ($file in $oldLocalFiles) {
				Remove-Item $file.FullName -Force -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "Deleted: $($file.Name)" -ForegroundColor Green }
				$OutputLines += "Deleted: $($file.Name)"
			}
			if (-not $NoConsoleOutput) { Write-Host "Old local Synology_* files deleted successfully." -ForegroundColor Green }
			$OutputLines += "Old local Synology_* files deleted successfully."
		}
		catch {
			if (-not $NoConsoleOutput) { Write-Warning "Could not delete one or more local files: $($_.Exception.Message)" }
			$OutputLines += "Warning: Could not delete one or more local files: $($_.Exception.Message)"
		}
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "`nNo old local Synology_* files found to delete." -ForegroundColor Yellow }
		$OutputLines += "No old local Synology_* files found to delete."
	}

	$summaryLine = if ($uploadSuccess) {
		"$ScriptName`: Synology config backup uploaded and cleanup completed successfully."
	} else {
		"$ScriptName`: Synology config backup upload failed."
	}

	$summaryColor = if ($uploadSuccess) { 'Green' } else { 'Red' }
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor $summaryColor }
	$OutputLines += $summaryLine
}

# Save results
if ($SaveResults) {
	try {
		$outputString = ($OutputLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.