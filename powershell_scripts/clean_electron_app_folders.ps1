# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans AppData\Local for app-* versioned folders and removes all but the newest version within each application directory

# NOTE: Electron-based apps (i.e. Claude, Discord, Slack, GitHub Desktop, etc.) commonly leave previous app-* folders behind after updates

# Optional flags:
#     -DeleteAll: Automatically delete all redundant app-* folders without prompting
#     -List: Show all app-* folders found without processing
#     -Preview: Show what would be deleted without making any changes
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Table: Show all app-* folders in table format (Name, FullName, LastWriteTime)
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$DeleteAll,
	[switch]$List,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Table,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-List] [-Preview] [-SaveResults <PATH>] [-Table] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll           Automatically delete all redundant app-* folders without prompting" -ForegroundColor Cyan
	Write-Host "  -List                Show all app-* folders found without processing" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would be deleted without making any changes" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Table               Show all app-* folders in table format (Name, FullName, LastWriteTime)" -ForegroundColor Cyan
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

$FileOutputLines = @()
$deletedCount = 0
$skippedCount = 0
$totalBytesFreed = 0

Write-Host "`nScanning $env:LOCALAPPDATA for app-* folders..." -ForegroundColor Cyan

# Find all app-* versioned folders recursively under AppData\Local
$appFolders = Get-ChildItem -Path $env:LOCALAPPDATA -Directory -Filter "app-*" -Recurse -ErrorAction SilentlyContinue |
	Where-Object { $_.Name -match '^app-(\d+(?:\.\d+)*)$' }

if (-not $appFolders -or $appFolders.Count -eq 0) {
	Write-Host "`nNo app-* folders found." -ForegroundColor Green
	exit 0
}

# -List: show all app-* folders as a simple list and exit
if ($List) {
	Write-Host ""
	$appFolders | Select-Object -ExpandProperty FullName
	Write-Host "`n$($appFolders.Count) app-* folder(s) found." -ForegroundColor Cyan
	exit 0
}

# -Table: show all app-* folders in table format and exit
if ($Table) {
	Write-Host ""
	$appFolders | Select-Object Name, FullName, LastWriteTime | Format-Table -AutoSize
	Write-Host "$($appFolders.Count) app-* folder(s) found." -ForegroundColor Cyan
	exit 0
}

# Group by immediate parent directory
$grouped = $appFolders | Group-Object { $_.Parent.FullName }

foreach ($group in $grouped) {
	# Skip groups with only one app-* folder — nothing to delete
	if ($group.Count -le 1) {
		$skippedCount++
		continue
	}

	# Sort by version descending and keep the highest
	$sorted = $group.Group | ForEach-Object {
		$_ | Add-Member -NotePropertyName ParsedVersion -NotePropertyValue ([version]($_.Name -replace '^app-', '')) -PassThru
	} | Sort-Object ParsedVersion -Descending

	$keep = $sorted | Select-Object -First 1
	$toDelete = $sorted | Select-Object -Skip 1

	$keepSize = (Get-ChildItem -Path $keep.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
	if (-not $keepSize) { $keepSize = 0 }
	$keepSizeMB = [math]::Round($keepSize / 1MB, 2)

	Write-Host "`n$($group.Name)" -ForegroundColor Cyan
	Write-Host "  Keeping: $($keep.Name) ($keepSizeMB MB)" -ForegroundColor Green
	if ($SaveResults) {
		$FileOutputLines += $group.Name
		$FileOutputLines += "  Keeping: $($keep.Name) ($keepSizeMB MB)"
	}

	foreach ($folder in $toDelete) {
		# Calculate folder size before deletion
		$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $folderSize) { $folderSize = 0 }

		if ($Preview) {
			$folderSizeMB = [math]::Round($folderSize / 1MB, 2)
			Write-Host "  Would delete: $($folder.Name) ($folderSizeMB MB)" -ForegroundColor Yellow
			if ($SaveResults) {
				$FileOutputLines += "  Would delete: $($folder.Name) ($folderSizeMB MB)"
			}
			$totalBytesFreed += $folderSize
			$deletedCount++
		}
		else {
			# Prompt unless -DeleteAll is specified
			if (-not $DeleteAll) {
				$response = Read-Host "`n  Delete '$($folder.Name)'? (Y/N)"
				if ($response -notmatch '^[Yy]$') {
					Write-Host "  Skipped: $($folder.Name)" -ForegroundColor Yellow
					if ($SaveResults) {
						$FileOutputLines += "  Skipped: $($folder.Name)"
					}
					continue
				}
			}

			try {
				$totalBytesFreed += $folderSize
				Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
				$folderSizeMB = [math]::Round($folderSize / 1MB, 2)
				Write-Host "  Deleted: $($folder.Name) ($folderSizeMB MB)" -ForegroundColor Yellow
				if ($SaveResults) {
					$FileOutputLines += "  Deleted: $($folder.Name) ($folderSizeMB MB)"
				}
				$deletedCount++
			}
			catch {
				Write-Host ""
				Write-Warning "Could not delete $($folder.FullName): $($_.Exception.Message)"
			}
		}
	}
}

# Format total bytes freed
$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" }
else { "$totalFreedMB MB" }

# Summary
if ($Preview) {
	$summaryLine = "$ScriptName`: Preview complete. $deletedCount folder(s) would be deleted, freeing approximately $freedDisplay."
	Write-Host "`n$summaryLine" -ForegroundColor Cyan
}
else {
	$summaryLine = "$ScriptName`: $deletedCount folder(s) deleted, $freedDisplay freed."
	Write-Host "`n$summaryLine" -ForegroundColor Green
}

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
		Write-Host "`nResults saved to text file: $SaveResults" -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.