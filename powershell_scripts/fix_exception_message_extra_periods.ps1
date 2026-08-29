# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a single script or a folder of scripts for an extra period at the end of $($_.Exception.Message) in Write-Error and Write-Warning lines and removes it

# Optional flags:
#     -Backup:             Automatically create backups before fixing files (skips interactive prompt)
#     -Fix:                Automatically fix issues without prompting
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults, and one of -Fix/-Preview)
#     -Path <PATH>:        Path to a .ps1 file or a folder (prompts if not specified)
#     -Preview:            Scan and report issues without fixing anything
#     -Recurse:            Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?:          Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Backup,
	[switch]$Fix,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Preview,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Backup] [-Fix] [-NoConsoleOutput] [-Path <PATH>] [-Preview] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Backup              Automatically create backups before fixing files (skips interactive prompt)" -ForegroundColor Cyan
	Write-Host "  -Fix                 Automatically fix issues without prompting" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults, and one of -Fix/-Preview)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a .ps1 file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview             Scan and report issues without fixing anything" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
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

# -NoConsoleOutput requires -SaveResults, and one of -Fix or -Preview, since without one of
# those this script can still block on interactive prompts with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not ($Fix -or $Preview) -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults, and one of -Fix or -Preview."
	exit 1
}

# Prompt user for file or folder path if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to a .ps1 file or a folder containing scripts"
}
$InputPath = $Path

if (-not (Test-Path -LiteralPath $InputPath)) {
	$errorMessage = "Path '$InputPath' does not exist."
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

$item = Get-Item -LiteralPath $InputPath

# Collect files
$files = if ($item.PSIsContainer) {
	Get-ChildItem -Path $InputPath -Filter *.ps1 -File -Recurse:$Recurse
}
else {
	if ($item.Extension -eq '.ps1') {
		@($item)
	}
	else {
		@()
	}
}

if (-not $files -or $files.Count -eq 0) {
	$warningMessage = "$ScriptName`: No PowerShell (.ps1) files found."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $warningMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, $warningMessage)
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

# Initialize counters and output lines
$issueCount = 0
$fixedCount = 0
$FileOutputLines = @()

if (-not $NoConsoleOutput) { Write-Host "`nScanning for trailing periods after `$(`$_.Exception.Message)...`n" -ForegroundColor Cyan }

# First pass: scan all files and collect issues
$fileIssuesMap = @{}

foreach ($file in $files) {
	try {
		$lines = @(Get-Content -LiteralPath $file.FullName -ErrorAction Stop)
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not read $($file.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) {
			$FileOutputLines += "Could not read $($file.Name): $($_.Exception.Message)"
		}
		continue
	}
	$fileIssues = @()

	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]

		if ($line -match '(Write-Error|Write-Warning).*?\$\(\$_\.Exception\.Message\)\.') {
			$fileIssues += "  Line $($i + 1): $($line.TrimStart())"
			$issueCount++
		}
	}

	if ($fileIssues.Count -gt 0) {
		$fileIssuesMap[$file.FullName] = $fileIssues
		$headerLine = "$($file.FullName):"
		if (-not $NoConsoleOutput) { Write-Host $headerLine -ForegroundColor Yellow }
		if ($SaveResults) {
			$FileOutputLines += $headerLine
		}

		foreach ($issue in $fileIssues) {
			if (-not $NoConsoleOutput) { Write-Host $issue -ForegroundColor Yellow }
			if ($SaveResults) {
				$FileOutputLines += $issue
			}
		}

		if (@($files).IndexOf($file) -lt ($files.Count - 1)) {
			if (-not $NoConsoleOutput) { Write-Host "" }
			if ($SaveResults) {
				$FileOutputLines += ""
			}
		}
	}
}

if ($issueCount -eq 0) {
	$summaryLine = "$ScriptName`: Scan complete. No trailing periods found."
	if (-not $NoConsoleOutput) { Write-Host $summaryLine -ForegroundColor Green }

	if ($SaveResults) {
		$FileOutputLines += $summaryLine
		try {
			$outputString = ($FileOutputLines -join "`n")
			[System.IO.File]::WriteAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

# Determine whether to fix
if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $issueCount instance(s) found. No fixes applied."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }

	if ($SaveResults) {
		$FileOutputLines += ""
		$FileOutputLines += $summaryLine

		while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
			$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
		}

		try {
			$outputString = ($FileOutputLines -join "`n")
			[System.IO.File]::WriteAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

$doFix = $false
if ($Fix) {
	$doFix = $true
}
else {
	Write-Host ""
	$fixResponse = Read-Host "Would you like to fix these issues? (Y/N)"
	if ($fixResponse -match '^[Yy]$') {
		$doFix = $true
	}
}

if (-not $doFix) {
	$summaryLine = "$ScriptName`: Scan complete. $issueCount instance(s) found. No fixes applied."
	if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }

	if ($SaveResults) {
		$FileOutputLines += ""
		$FileOutputLines += $summaryLine

		while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
			$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
		}

		try {
			$outputString = ($FileOutputLines -join "`n")
			[System.IO.File]::WriteAllText($SaveResults, $outputString)
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}

	exit 0
}

# Determine whether to create backups
$doBackup = $false
if ($Backup) {
	$doBackup = $true
}
else {
	if (-not $Fix) {
		Write-Host ""
		$backupResponse = Read-Host "Would you like to create backups before fixing? (Y/N)"
		if ($backupResponse -match '^[Yy]$') {
			$doBackup = $true
		}
	}
}

# Second pass: fix files
$firstFix = $true
$firstFixFile = $true
foreach ($file in $files) {
	if (-not $fileIssuesMap.ContainsKey($file.FullName)) {
		continue
	}

	if ($firstFixFile) {
		if (-not $NoConsoleOutput) { Write-Host "" }
		$firstFixFile = $false
		if ($SaveResults) {
			$FileOutputLines += ""
		}
	}

	$lines = @(Get-Content -LiteralPath $file.FullName)
	$newLines = @()

	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]
		if ($line -match '(Write-Error|Write-Warning).*?\$\(\$_\.Exception\.Message\)\.') {
			$line = $line -replace '(\$\(\$_\.Exception\.Message\))\.', '$1'
			$fixedCount++
		}
		$newLines += $line
	}

	try {
		if ($doBackup) {
			$backupPath = $file.FullName + ".bak"
			Copy-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
			if (-not $NoConsoleOutput) { Write-Host "Backup created: $backupPath" -ForegroundColor Cyan }
			if ($SaveResults) {
				$FileOutputLines += "Backup created: $backupPath"
			}
		}

		$utf8Bom = New-Object System.Text.UTF8Encoding $true
		[System.IO.File]::WriteAllText($file.FullName, ($newLines -join "`r`n"), $utf8Bom)
		if ($firstFix -and -not $doBackup) {
			$firstFix = $false
		}
		if (-not $NoConsoleOutput) { Write-Host "Fixed: $($file.Name)" -ForegroundColor Green }
		if ($SaveResults) {
			$FileOutputLines += "Fixed: $($file.Name)"
		}
	}
	catch {
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning "Could not write to $($file.Name): $($_.Exception.Message)"
		}
		if ($SaveResults) {
			$FileOutputLines += "Could not write to $($file.Name): $($_.Exception.Message)"
		}
	}
}

# Summary
$summaryLine = "$ScriptName`: Scan complete. $issueCount instance(s) found, $fixedCount fixed."
if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }

# Save results to text file if requested
if ($SaveResults) {
	$FileOutputLines += ""
	$FileOutputLines += $summaryLine

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

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.