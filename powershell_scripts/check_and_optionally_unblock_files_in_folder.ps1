# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a user-supplied folder for files that are blocked from running and optionally unblocks them

# NOTE: Admin is required to unblock files in protected system folders. Remove #Requires -RunAsAdministrator if not needed.

# Optional flags:
#     -Backup: Automatically create backups before unblocking files (skips interactive prompt)
#     -Filenames: Show filenames only instead of full paths
#     -Recurse: Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -UnblockAll: Automatically unblock all blocked files without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$Filenames,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$UnblockAll,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-Filenames] [-Recurse] [-UnblockAll] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before unblocking files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show filenames only instead of full paths" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -UnblockAll          Automatically unblock all blocked files without prompting" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# Prompt the user for the folder to process
$Path = Read-Host "`nEnter the directory to scan"

if (-not (Test-Path -Path $Path -PathType Container)) {
	Write-Error "The specified path does not exist or is not a directory."
	exit 1
}

# Scan the user-supplied folder
Write-Host "`nScanning directory: $Path" -ForegroundColor Cyan

try {
	$files = Get-ChildItem -Path $Path -Recurse:$Recurse -File -ErrorAction Stop
}
catch {
	Write-Error "Error enumerating files: $($_.Exception.Message)"
	exit 1
}

$blockedFiles = @()
$checkErrors = @()
$FileOutputLines = @()

foreach ($file in $files) {
	# Check for and record blocked files
	try {
		$null = Get-Item -Path $file.FullName -Stream Zone.Identifier -ErrorAction Stop
		$blockedFiles += $file
	}
	catch {
		# Ignore "stream not found" errors (means file is not blocked)
		if ($_.Exception.Message -notmatch "Zone.Identifier") {
			$checkErrors += [PSCustomObject]@{
				File  = $file.FullName
				Error = $_.Exception.Message
			}
		}
	}
}

if ($blockedFiles.Count -eq 0) {
	Write-Host "`nNo blocked files found." -ForegroundColor Green
	exit 0
}

# Display all blocked file paths
Write-Host "`nBlocked files:" -ForegroundColor Yellow
$blockedFiles | Sort-Object Name | ForEach-Object {
	$displayName = if ($Filenames) { $_.Name } else { $_.FullName }
	Write-Host "  $displayName" -ForegroundColor Yellow
	if ($SaveResults) {
		$FileOutputLines += $displayName
	}
}

# Show summary and any check errors
Write-Host "`nBlocked files found: $($blockedFiles.Count)" -ForegroundColor Yellow
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += "Blocked files found: $($blockedFiles.Count)"
}

if ($checkErrors.Count -gt 0) {
	Write-Host "`nSome files could not be checked:" -ForegroundColor Yellow
	foreach ($err in $checkErrors) {
		Write-Host "  File: $($err.File)" -ForegroundColor Red
		Write-Host "  Error: $($err.Error)" -ForegroundColor Red
		if ($SaveResults) {
			$FileOutputLines += "File: $($err.File)"
			$FileOutputLines += "Error: $($err.Error)"
		}
	}
}

# Prompt the user to optionally unblock all files
if ($UnblockAll) {
	$response = 'Y'
}
else {
	$response = Read-Host "`nUnblock ALL listed files? (Y/N)"
}

if ($response -match '^[Yy]$') {
	# Determine whether to create backups
	$doBackup = $false
	if ($Backup) {
		$doBackup = $true
	}
	else {
		if (-not $UnblockAll) {
			Write-Host ""
			$backupResponse = Read-Host "Would you like to create backups before unblocking? (Y/N)"
			if ($backupResponse -match '^[Yy]$') {
				$doBackup = $true
			}
		}
	}

	$unblockErrors = @()
	if ($SaveResults) {
		$FileOutputLines += ""
	}
	Write-Host ""
	foreach ($file in $blockedFiles) {
		try {
			if ($doBackup) {
				$backupPath = $file.FullName + ".bak"
				Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
				Write-Host "Backup created: $backupPath" -ForegroundColor Cyan
				if ($SaveResults) {
					$FileOutputLines += "Backup created: $backupPath"
				}
			}

			Unblock-File -Path $file.FullName -ErrorAction Stop
			$displayName = if ($Filenames) { $file.Name } else { $file.FullName }
			Write-Host "Unblocked: $displayName" -ForegroundColor Green
			if ($SaveResults) {
				$FileOutputLines += "Unblocked: $displayName"
			}
		}
		catch {
			$unblockErrors += [PSCustomObject]@{
				File  = $file.FullName
				Error = $_.Exception.Message
			}
		}
	}

	Write-Host "`nUnblock operation complete. $($blockedFiles.Count) file(s) unblocked." -ForegroundColor Green
	if ($SaveResults) {
		$FileOutputLines += ""
		$FileOutputLines += "Unblock operation complete. $($blockedFiles.Count) file(s) unblocked."
	}

	if ($unblockErrors.Count -gt 0) {
		Write-Host "`nSome files failed to unblock:" -ForegroundColor Yellow
		foreach ($err in $unblockErrors) {
			Write-Host "  File: $($err.File)" -ForegroundColor Red
			Write-Host "  Error: $($err.Error)" -ForegroundColor Red
			if ($SaveResults) {
				$FileOutputLines += "File: $($err.File)"
				$FileOutputLines += "Error: $($err.Error)"
			}
		}
	}
}
else {
	Write-Host "`nNo files were modified." -ForegroundColor Yellow
	if ($SaveResults) {
		$FileOutputLines += "No files were modified."
	}
}

# Save results if requested
if ($SaveResults) {
	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	$outputString = ($FileOutputLines -join "`n")
	[System.IO.File]::WriteAllText($SaveResults, $outputString)

	Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.