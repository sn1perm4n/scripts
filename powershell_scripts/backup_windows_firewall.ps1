# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script backs up the Windows Firewall configuration to a .wfw file. By default the backup is saved to %USERPROFILE%\Desktop. Use -Backup <PATH> to override the destination. Use -Sftp to also upload the backup to a remote server via SFTP using WinSCP.
# Use Invoke-PS2EXE -InputFile "PATH\TO\MyScript.ps1" -OutputFile "PATH\TO\MyScript.exe" to turn this script into a .exe to hide the password
# If flags are required, create a shortcut to the .exe and pass them after -end when running the .exe: .\MyScript.exe -end -YourParam1 Value1 -YourFlag2 (be aware the Windows shortcut Target field has a 259 character limit)

# NOTE: SFTP credentials are hardcoded in the script. Update HostName, UserName, Password, and SshHostKeyFingerprint before using -Sftp

# NOTE2: When using -Interactive, HostName and UserName are prompted at runtime and Password is prompted securely. SshHostKeyFingerprint must still be hardcoded in the script.

# NOTE3: The WinSCP session log is saved alongside the .wfw backup file as WinSCP.log when -Sftp is used (use -NoLog to suppress it)

# NOTE4: WinSCP's .NET assembly is incompatible with PowerShell 7.x due to missing .NET Framework APIs. This script automatically re-launches itself under PowerShell 5.1 when run from PowerShell 7.x. If WinSCP releases a .NET 6+ compatible assembly in a future version, the re-launch block below can be removed. Use -TestCompatibility to check if the current WinSCP version works natively under PowerShell 7.x.

# Optional flags:
#     -Backup <PATH>: Override the default backup destination (%USERPROFILE%\Desktop)
#     -Interactive: Prompt for SFTP credentials at runtime instead of using hardcoded values (requires -Sftp)
#     -NoConsoleOutput: Suppress all console output (requires -SaveResults)
#     -NoLog: Suppress the WinSCP session log file (only relevant with -Sftp)
#     -Preview: Show what would happen without actually creating the backup or uploading
#     -SaveResults <PATH>: Save console output to a text file
#     -Sftp: Upload the backup to a remote server via SFTP using WinSCP after creating it
#     -TestCompatibility: Test whether WinSCP works natively under the current PowerShell version
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[string]$Backup,
	[switch]$Interactive,
	[switch]$NoConsoleOutput,
	[switch]$NoLog,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Sftp,
	[switch]$TestCompatibility,
	[switch]$Help
)

# Re-launch under PowerShell 5.1 if running under PowerShell 7.x (WinSCP .NET assembly incompatibility)
if ($PSVersionTable.PSVersion.Major -ge 7 -and -not $TestCompatibility) {
	$argList = @('-NonInteractive', '-NoProfile', '-File', $PSCommandPath)
	foreach ($key in $MyInvocation.BoundParameters.Keys) {
		$val = $MyInvocation.BoundParameters[$key]
		if ($val -is [switch]) { $argList += "-$key" }
		else { $argList += "-$key", $val }
	}
	powershell.exe @argList
	exit $LASTEXITCODE
}

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup <PATH>] [-Interactive] [-NoConsoleOutput] [-NoLog] [-Preview] [-SaveResults <PATH>] [-Sftp] [-TestCompatibility] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup <PATH>        Override the default backup destination (%USERPROFILE%\Desktop)" -ForegroundColor Cyan
	Write-Host "  -Interactive          Prompt for SFTP credentials at runtime instead of using hardcoded values (requires -Sftp)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput      Suppress all console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -NoLog                Suppress the WinSCP session log file (only relevant with -Sftp)" -ForegroundColor Cyan
	Write-Host "  -Preview              Show what would happen without actually creating the backup or uploading" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>   Save console output to a text file" -ForegroundColor Cyan
	Write-Host "  -Sftp                 Upload the backup to a remote server via SFTP using WinSCP after creating it" -ForegroundColor Cyan
	Write-Host "  -TestCompatibility    Test whether WinSCP works natively under the current PowerShell version" -ForegroundColor Cyan
	Write-Host "  -Help                 Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Handle -TestCompatibility
if ($TestCompatibility) {
	$winScpDll = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
	Write-Host "`nTesting WinSCP compatibility under PowerShell $($PSVersionTable.PSVersion)..." -ForegroundColor Cyan
	if (-not (Test-Path $winScpDll)) {
		Write-Warning "WinSCP is not installed or WinSCPnet.dll was not found at: $winScpDll"
		exit 1
	}
	try {
		Add-Type -Path $winScpDll
		$testOptions = New-Object WinSCP.SessionOptions
		$null = $testOptions
		Write-Host "WinSCP is compatible with PowerShell $($PSVersionTable.PSVersion). The PS 5.1 re-launch block in this script can be removed." -ForegroundColor Green
		exit 0
	}
	catch {
		Write-Host "WinSCP is NOT compatible with PowerShell $($PSVersionTable.PSVersion): $($_.Exception.Message)" -ForegroundColor Yellow
		Write-Host "The PS 5.1 re-launch block should remain in place." -ForegroundColor Yellow
		exit 1
	}
}

# Warn on unsupported flag combinations
if ($Interactive -and -not $Sftp) {
	Write-Host ""
	Write-Warning "-Interactive requires -Sftp. SFTP credentials are only used when -Sftp is specified."
	exit 1
}

if ($Interactive -and $Preview) {
	Write-Host ""
	Write-Warning "-Interactive and -Preview cannot be used together. -Preview is a credential-free dry run; use one or the other."
	exit 1
}

if ($Interactive -and $NoConsoleOutput) {
	Write-Host ""
	Write-Warning "-Interactive cannot be used with -NoConsoleOutput as credential prompts require console interaction."
	exit 1
}

if ($NoLog -and -not $Sftp) {
	Write-Host ""
	Write-Warning "-NoLog is only relevant when -Sftp is specified."
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
$backupPath = if ($Backup) { $Backup }
else { "$env:USERPROFILE\Desktop" }
$backupFilename = "Windows_Firewall_Backup_$(Get-Date -Format 'MM-dd-yyyy').wfw"
$fullBackupFilePath = Join-Path -Path $backupPath -ChildPath $backupFilename
$logPath = Join-Path -Path $backupPath -ChildPath "WinSCP.log"

# SFTP settings (update before using -Sftp)
$remotePath = "/mnt/path/to/remote/Windows Firewall/$backupFilename"
$sftpHost = "HOSTNAME"
$sftpUser = "USERNAME"
$sftpPassword = "PASSWORD"
$sftpFingerprint = "ssh-ed25519 256 YOUR_FINGERPRINT_HERE"

# Prompt for credentials if -Interactive is specified
if ($Interactive) {
	Write-Host ""
	$sftpHost = Read-Host "Enter SFTP hostname"
	$sftpUser = Read-Host "Enter SFTP username"
	$sftpSecurePassword = Read-Host "Enter SFTP password" -AsSecureString
	$sftpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
		[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sftpSecurePassword)
	)
}

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
		if (-not $NoLog) {
			if (-not $NoConsoleOutput) { Write-Host "Would save WinSCP session log to: $logPath" -ForegroundColor Cyan }
			$OutputLines += "Would save WinSCP session log to: $logPath"
		}
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
	$uploadSuccess = $false
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

			if ($NoLog) {
				if (-not $NoConsoleOutput) { Write-Host "`nWinSCP session logging is disabled." -ForegroundColor Yellow }
				$OutputLines += "WinSCP session logging is disabled."
			}

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
				if (-not $NoLog) { $session.SessionLogPath = $logPath }
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
				$uploadSuccess = $true
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

	$summaryLine = if ($Sftp -and $backupSuccess -and $uploadSuccess) {
		"$ScriptName`: Backup and SFTP upload completed successfully."
	}
	elseif ($Sftp -and $backupSuccess -and -not $uploadSuccess) {
		"$ScriptName`: Backup completed successfully but SFTP upload failed."
	}
	elseif ($backupSuccess) {
		"$ScriptName`: Backup completed successfully."
	}
	else {
		"$ScriptName`: Backup failed."
	}

	$summaryColor = if ($backupSuccess -and (-not $Sftp -or $uploadSuccess)) { 'Green' } else { 'Red' }
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor $summaryColor }
	$OutputLines += $summaryLine
}

# Save results
if ($SaveResults) {
	try {
		while ($OutputLines.Count -gt 0 -and $OutputLines[-1] -eq '') {
			$OutputLines = $OutputLines[0..($OutputLines.Count - 2)]
		}
		$outputString = ($OutputLines -join "`n")
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