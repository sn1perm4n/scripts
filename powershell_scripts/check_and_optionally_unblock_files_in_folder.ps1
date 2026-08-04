# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a user-supplied folder for files that are blocked from running and optionally unblocks them

# NOTE: Admin is required to unblock files in protected system folders. Remove #Requires -RunAsAdministrator if not needed.

# Optional flags:
#     -Backup: Automatically create backups before unblocking files (skips interactive prompt)
#     -Filenames: Show filenames only instead of full paths
#     -NoConsoleOutput: Suppress console output (requires -UnblockAll and -SaveResults)
#     -Path <PATH>: Path to a folder (prompts if not specified)
#     -Recurse: Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -UnblockAll: Automatically unblock all blocked files without prompting
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$Filenames,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$UnblockAll,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-Filenames] [-NoConsoleOutput] [-Path <PATH>] [-Recurse] [-UnblockAll] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before unblocking files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show filenames only instead of full paths" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -UnblockAll and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -UnblockAll          Automatically unblock all blocked files without prompting" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
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

# -NoConsoleOutput requires -UnblockAll and -SaveResults, since without -UnblockAll this script
# can still block on interactive prompts with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $UnblockAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -UnblockAll and -SaveResults."
	exit 1
}

# Prompt user for folder path if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to a folder"
}

if (-not (Test-Path -Path $Path -PathType Container)) {
	$errorMessage = "The specified path does not exist or is not a directory."
	if ($NoConsoleOutput) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Error $errorMessage
		}
	}
	else {
		Write-Host ""
		Write-Error $errorMessage
	}
	exit 1
}

# Scan the user-supplied folder
if (-not $NoConsoleOutput) { Write-Host "`nScanning directory: $Path" -ForegroundColor Cyan }

try {
	$files = Get-ChildItem -Path $Path -Recurse:$Recurse -File -ErrorAction Stop
}
catch {
	$errorMessage = "Error enumerating files: $($_.Exception.Message)"
	if ($NoConsoleOutput) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Error $errorMessage
		}
	}
	else {
		Write-Host ""
		Write-Error $errorMessage
	}
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
				File = $file.FullName
				Error = $_.Exception.Message
			}
		}
	}
}

if ($blockedFiles.Count -eq 0) {
	if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: No blocked files found." -ForegroundColor Green }
	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, "$ScriptName`: No blocked files found.")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

# Display all blocked file paths
if (-not $NoConsoleOutput) { Write-Host "`nBlocked files:" -ForegroundColor Yellow }
$blockedFiles | Sort-Object Name | ForEach-Object {
	$displayName = if ($Filenames) { $_.Name } else { $_.FullName }
	if (-not $NoConsoleOutput) { Write-Host "  $displayName" -ForegroundColor Yellow }
	if ($SaveResults) {
		$FileOutputLines += $displayName
	}
}

# Show summary and any check errors
if (-not $NoConsoleOutput) {
	Write-Host ""
	Write-Warning "Blocked files found: $($blockedFiles.Count)"
}
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += "Blocked files found: $($blockedFiles.Count)"
}

if ($checkErrors.Count -gt 0) {
	if (-not $NoConsoleOutput) { Write-Host "`nSome files could not be checked:" -ForegroundColor Yellow }
	foreach ($err in $checkErrors) {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "File: $($err.File) — $($err.Error)"
		}
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
	if (-not $NoConsoleOutput) { Write-Host "" }
	foreach ($file in $blockedFiles) {
		try {
			if ($doBackup) {
				$backupPath = $file.FullName + ".bak"
				Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
				if (-not $NoConsoleOutput) { Write-Host "Backup created: $backupPath" -ForegroundColor Cyan }
				if ($SaveResults) {
					$FileOutputLines += "Backup created: $backupPath"
				}
			}

			Unblock-File -Path $file.FullName -ErrorAction Stop
			$displayName = if ($Filenames) { $file.Name } else { $file.FullName }
			if (-not $NoConsoleOutput) { Write-Host "Unblocked: $displayName" -ForegroundColor Green }
			if ($SaveResults) {
				$FileOutputLines += "Unblocked: $displayName"
			}
		}
		catch {
			$unblockErrors += [PSCustomObject]@{
				File = $file.FullName
				Error = $_.Exception.Message
			}
		}
	}

	if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Unblock operation complete. $($blockedFiles.Count) file(s) unblocked." -ForegroundColor Green }
	if ($SaveResults) {
		$FileOutputLines += ""
		$FileOutputLines += "$ScriptName`: Unblock operation complete. $($blockedFiles.Count) file(s) unblocked."
	}

	if ($unblockErrors.Count -gt 0) {
		if (-not $NoConsoleOutput) { Write-Host "`nSome files failed to unblock:" -ForegroundColor Yellow }
		foreach ($err in $unblockErrors) {
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning "File: $($err.File) — $($err.Error)"
			}
			if ($SaveResults) {
				$FileOutputLines += "File: $($err.File)"
				$FileOutputLines += "Error: $($err.Error)"
			}
		}
	}
}
else {
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning "$ScriptName`: No files were modified."
	}
	if ($SaveResults) {
		$FileOutputLines += "$ScriptName`: No files were modified."
	}
}

# Save results to text file if requested
if ($SaveResults) {
	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
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