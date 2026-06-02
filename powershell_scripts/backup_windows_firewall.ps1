# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the Windows Firewall configuration to a .wfw file. By default the backup is saved to %USERPROFILE%\Desktop. Use -Backup <PATH> to override the destination. Use -Sftp to also upload the backup to a remote server via SFTP using WinSCP.

# NOTE: SFTP credentials are hardcoded in the script. Update HostName, UserName, Password, and SshHostKeyFingerprint before using -Sftp

# NOTE2: The WinSCP session log is saved alongside the .wfw backup file as WinSCP.log when -Sftp is used

# Optional flags:
#     -Backup <PATH>: Override the default backup destination (%USERPROFILE%\Desktop)
#     -NoConsoleOutput: Suppress all console output (requires -SaveResults)
#     -Preview: Show what would happen without actually creating the backup or uploading
#     -SaveResults <PATH>: Save console output to a text file
#     -Sftp: Upload the backup to a remote server via SFTP using WinSCP after creating it
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[string]$Backup,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Sftp,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup <PATH>] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Sftp] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup <PATH>       Override the default backup destination (%USERPROFILE%\Desktop)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress all console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would happen without actually creating the backup or uploading" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save console output to a text file" -ForegroundColor Cyan
	Write-Host "  -Sftp                Upload the backup to a remote server via SFTP using WinSCP after creating it" -ForegroundColor Cyan
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

# Set backup destination
$backupPath = if ($Backup) { $Backup } else { "$env:USERPROFILE\Desktop" }
$backupFilename = "Windows_Firewall_Backup_$(Get-Date -Format 'MM-dd-yyyy').wfw"
$fullBackupFilePath = Join-Path -Path $backupPath -ChildPath $backupFilename
$logPath = Join-Path -Path $backupPath -ChildPath "WinSCP.log"

# SFTP settings (update before using -Sftp)
$remotePath = "/mnt/path/to/remote/$backupFilename"
$sftpHost = "HOSTNAME"
$sftpUser = "USERNAME"
$sftpPassword = "PASSWORD"
$sftpFingerprint = "ssh-ed25519 256 44:29:e2:b6:ff:45:55:a8:f9:15:36:4a:40:8b:1a:86"

$OutputLines = @()

if ($Preview) {
	if (-not $NoConsoleOutput) { Write-Host "`nPreview mode — no changes will be made." -ForegroundColor Cyan }
	$OutputLines += "Preview mode — no changes will be made."
	if (-not $NoConsoleOutput) { Write-Host "`nWould delete existing backup if present: $fullBackupFilePath" -ForegroundColor Cyan }
	$OutputLines += "Would delete existing backup if present: $fullBackupFilePath"
	if (-not $NoConsoleOutput) { Write-Host "Would create backup at: $fullBackupFilePath" -ForegroundColor Cyan }
	$OutputLines += "Would create backup at: $fullBackupFilePath"
	if ($Sftp) {
		if (-not $NoConsoleOutput) { Write-Host "Would upload to SFTP: $remotePath" -ForegroundColor Cyan }
		$OutputLines += "Would upload to SFTP: $remotePath"
		if (-not $NoConsoleOutput) { Write-Host "Would save WinSCP session log to: $logPath" -ForegroundColor Cyan }
		$OutputLines += "Would save WinSCP session log to: $logPath"
	}
	if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Preview complete." -ForegroundColor Cyan }
	$OutputLines += "$ScriptName`: Preview complete."
}
else {
	# Delete existing backup file if it exists
	if (Test-Path $fullBackupFilePath) {
		try {
			Remove-Item $fullBackupFilePath -Force -ErrorAction Stop
			if (-not $NoConsoleOutput) { Write-Host "`nExisting backup file deleted." -ForegroundColor Green }
			$OutputLines += "Existing backup file deleted."
		}
		catch {
			if (-not $NoConsoleOutput) { Write-Warning "Could not delete existing backup file: $($_.Exception.Message)" }
			$OutputLines += "Warning: Could not delete existing backup file: $($_.Exception.Message)"
		}
	}

	# Export the Windows Firewall configuration
	$backupSuccess = $false
	try {
		netsh advfirewall export "$fullBackupFilePath" > $null
		if (-not $NoConsoleOutput) { Write-Host "`nWindows Firewall configuration successfully backed up to: $fullBackupFilePath." -ForegroundColor Green }
		$OutputLines += "Windows Firewall configuration successfully backed up to: $fullBackupFilePath."
		$backupSuccess = $true
	}
	catch {
		if (-not $NoConsoleOutput) { Write-Error "Failed to back up Windows Firewall configuration: $($_.Exception.Message)" }
		$OutputLines += "Failed to back up Windows Firewall configuration: $($_.Exception.Message)"
	}

	# Upload via SFTP if -Sftp is specified and backup succeeded
	if ($Sftp -and $backupSuccess) {
		$winScpDll = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
		if (-not (Test-Path $winScpDll)) {
			if (-not $NoConsoleOutput) { Write-Warning "WinSCP is not installed or WinSCPnet.dll was not found at: $winScpDll" }
			$OutputLines += "Warning: WinSCP is not installed or WinSCPnet.dll was not found at: $winScpDll"
			if (-not $NoConsoleOutput) { Write-Host "Please install WinSCP from https://winscp.net and re-run with -Sftp." -ForegroundColor Yellow }
			$OutputLines += "Please install WinSCP from https://winscp.net and re-run with -Sftp."
		}
		else {
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
			$transferResult = $null
			try {
				$session.SessionLogPath = $logPath
				$session.Open($sessionOptions)

				$remoteDir = [System.IO.Path]::GetDirectoryName($remotePath) -replace '\\', '/'
				try {
					if (-not $NoConsoleOutput) { Write-Host "`nEmptying remote directory: $remoteDir." -ForegroundColor Yellow }
					$OutputLines += "Emptying remote directory: $remoteDir."
					$session.RemoveFiles("$remoteDir/*").Check()
					if (-not $NoConsoleOutput) { Write-Host "Remote directory emptied successfully." -ForegroundColor Green }
					$OutputLines += "Remote directory emptied successfully."
				}
				catch { $null = $_ }

				$transferResult = $session.PutFiles($fullBackupFilePath, $remotePath, $false)
				$transferResult.Check()
				if (-not $NoConsoleOutput) { Write-Host "Upload succeeded: $($transferResult.Transfers[0].FileName)" -ForegroundColor Green }
				$OutputLines += "Upload succeeded: $($transferResult.Transfers[0].FileName)"
			}
			catch {
				if (-not $NoConsoleOutput) { Write-Warning "SFTP upload failed: $($_.Exception.Message)" }
				$OutputLines += "Warning: SFTP upload failed: $($_.Exception.Message)"
			}
			finally {
				$session.Dispose()
			}
		}
	}

	$summaryLine = if ($Sftp -and $backupSuccess) {
		"$ScriptName`: Backup and SFTP upload completed successfully."
	} elseif ($backupSuccess) {
		"$ScriptName`: Backup completed successfully."
	} else {
		"$ScriptName`: Backup failed."
	}

	$summaryColor = if ($backupSuccess) { 'Green' } else { 'Red' }
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