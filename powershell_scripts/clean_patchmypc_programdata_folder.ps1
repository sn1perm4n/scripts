# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all folders and all files except the *.aiu file in:
# C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates

# Optional flags:
#     -DeleteAll:            Automatically delete without prompting
#     -NoConsoleOutput:      Suppress console output (requires -SaveResults and -DeleteAll)
#     -Preview:              Show what would be deleted without making any changes
#     -SaveResults <PATH>:   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Help / -?:            Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$DeleteAll,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll            Automatically delete without prompting" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput      Suppress console output (requires -SaveResults and -DeleteAll)" -ForegroundColor Cyan
	Write-Host "  -Preview              Show what would be deleted without making any changes" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Help                 Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -NoConsoleOutput requires -SaveResults and -DeleteAll, since without -DeleteAll this script
# can still block on an interactive prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $SaveResults -or -not $DeleteAll)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults and -DeleteAll."
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

# Specify the directory to process
$programdataPatchmypcFolder = 'C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates'

if (-not $NoConsoleOutput) { Write-Host "`nChecking '$programdataPatchmypcFolder'..." -ForegroundColor Cyan }

# Guard clauses
if (-not (Test-Path $programdataPatchmypcFolder)) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] The directory '$programdataPatchmypcFolder' does not exist."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $summaryLine
	}
	$resultLines += $summaryLine
}
elseif (-not (Get-ChildItem -Path $programdataPatchmypcFolder -Force)) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] The directory '$programdataPatchmypcFolder' is empty."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $summaryLine
	}
	$resultLines += $summaryLine
}
else {
	$files = @(Get-ChildItem -Path $programdataPatchmypcFolder -File)
	$folders = @(Get-ChildItem -Path $programdataPatchmypcFolder -Directory)

	# Keep only the *.aiu file (the update-check metadata the program actually needs); everything else here is disposable installer/artifact content
	$aiuFiles = @($files | Where-Object { $_.Extension -eq '.aiu' })
	$latestAiuFile = $null
	if ($aiuFiles.Count -gt 0) {
		$latestAiuFile = $aiuFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	}

	$filesToDelete = @($files | Where-Object { -not $latestAiuFile -or $_.FullName -ne $latestAiuFile.FullName })

	if ($Preview) {
		$bytesToFree = ($filesToDelete | Measure-Object -Property Length -Sum).Sum
		foreach ($folder in $folders) {
			$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
			if ($folderSize) { $bytesToFree += $folderSize }
		}
		if (-not $bytesToFree) { $bytesToFree = 0 }

		$freeMB = [math]::Round($bytesToFree / 1MB, 2)
		$freeGB = [math]::Round($bytesToFree / 1GB, 2)
		$freeDisplay = if ($bytesToFree -ge 1GB) { "$freeGB GB" }
		else { "$freeMB MB" }

		# The console gets a readable multi-line breakdown; $summaryLine stays a single compact line for -SaveResults, matching every other script's one-line-per-log-entry convention
		$keepLine = if ($latestAiuFile) { "Would keep: $($latestAiuFile.FullName)." } else { "No .aiu file found - nothing would be kept." }
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. $keepLine Would delete $($filesToDelete.Count) file(s) and $($folders.Count) folder(s) ($freeDisplay). No changes were made."

		if (-not $NoConsoleOutput) {
			# Name lists are capped at 3 with an "and N more" suffix, so this stays readable even when deleting hundreds or thousands of items
			$fileNamesPreview = ''
			if ($filesToDelete.Count -gt 0) {
				$fileNamesList = ($filesToDelete | Select-Object -First 3 -ExpandProperty Name) -join ', '
				if ($filesToDelete.Count -gt 3) { $fileNamesList += ", and $($filesToDelete.Count - 3) more" }
				$fileNamesPreview = ": $fileNamesList"
			}
			$folderNamesPreview = ''
			if ($folders.Count -gt 0) {
				$folderNamesList = ($folders | Select-Object -First 3 -ExpandProperty Name) -join ', '
				if ($folders.Count -gt 3) { $folderNamesList += ", and $($folders.Count - 3) more" }
				$folderNamesPreview = ": $folderNamesList"
			}

			Write-Host "`nPreview complete:" -ForegroundColor Yellow
			Write-Host "  Keep:   $(if ($latestAiuFile) { $latestAiuFile.Name } else { '(no .aiu file found)' })" -ForegroundColor Yellow
			Write-Host "  Delete: $($filesToDelete.Count) file(s)$fileNamesPreview" -ForegroundColor Yellow
			Write-Host "  Delete: $($folders.Count) folder(s)$folderNamesPreview" -ForegroundColor Yellow
			Write-Host "  Total:  $freeDisplay" -ForegroundColor Yellow
		}
		$resultLines += $summaryLine
	}
	else {
		$totalToDelete = $filesToDelete.Count + $folders.Count

		$proceedWithDelete = $true
		if ($totalToDelete -gt 0 -and -not $DeleteAll) {
			if (-not $NoConsoleOutput) {
				# Name lists are capped at 3 with an "and N more" suffix, so this stays readable even when deleting hundreds or thousands of items
				$fileNamesPreview = ''
				if ($filesToDelete.Count -gt 0) {
					$fileNamesList = ($filesToDelete | Select-Object -First 3 -ExpandProperty Name) -join ', '
					if ($filesToDelete.Count -gt 3) { $fileNamesList += ", and $($filesToDelete.Count - 3) more" }
					$fileNamesPreview = ": $fileNamesList"
				}
				$folderNamesPreview = ''
				if ($folders.Count -gt 0) {
					$folderNamesList = ($folders | Select-Object -First 3 -ExpandProperty Name) -join ', '
					if ($folders.Count -gt 3) { $folderNamesList += ", and $($folders.Count - 3) more" }
					$folderNamesPreview = ": $folderNamesList"
				}

				Write-Host "`nFound:" -ForegroundColor Cyan
				Write-Host "  $($filesToDelete.Count) file(s)$fileNamesPreview" -ForegroundColor Cyan
				Write-Host "  $($folders.Count) folder(s)$folderNamesPreview" -ForegroundColor Cyan
			}
			$response = Read-Host "`nDelete them now? (Y/N)"
			if ($response -notmatch '^[Yy]$') {
				$proceedWithDelete = $false
				$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Deletion skipped by user."
				if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }
				$resultLines += $summaryLine
			}
		}

		if ($proceedWithDelete) {
			if (-not $aiuFiles) {
				Write-Host ""
				Write-Warning "No .aiu file found in '$programdataPatchmypcFolder' - nothing will be kept."
			}
			elseif (-not $NoConsoleOutput) {
				Write-Host "`nKeeping file: $($latestAiuFile.FullName)" -ForegroundColor Green
			}

			try {
				$totalBytesFreed = 0
				$deletedFilesCount = 0
				$deletedFoldersCount = 0

				foreach ($file in $filesToDelete) {
					$totalBytesFreed += $file.Length
					if (-not $NoConsoleOutput) { Write-Host "Deleting file: $($file.FullName)" -ForegroundColor Yellow }
					Remove-Item $file.FullName -Force
					$deletedFilesCount++
				}

				foreach ($folder in $folders) {
					$folderSize = (Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
					if (-not $folderSize) { $folderSize = 0 }
					$totalBytesFreed += $folderSize
					if (-not $NoConsoleOutput) { Write-Host "Deleting folder: $($folder.FullName)" -ForegroundColor Yellow }
					Remove-Item $folder.FullName -Recurse -Force
					$deletedFoldersCount++
				}

				$totalDeleted = $deletedFilesCount + $deletedFoldersCount
				if ($totalDeleted -gt 0) {
					$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
					$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
					$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" }
					else { "$totalFreedMB MB" }
					$fileWord = if ($deletedFilesCount -eq 1) { "file" } else { "files" }
					$folderWord = if ($deletedFoldersCount -eq 1) { "folder" } else { "folders" }
					$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] $deletedFilesCount $fileWord and $deletedFoldersCount $folderWord deleted, $freedDisplay freed."
					if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
				}
				else {
					$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] No deletions were necessary."
					if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }
				}
				$resultLines += $summaryLine
			}
			catch {
				$errorLine = "$ScriptName`: [$env:COMPUTERNAME] An error occurred while trying to delete items in '$programdataPatchmypcFolder': $($_.Exception.Message)"
				Write-Host ""
				Write-Error $errorLine
				$resultLines += $errorLine
			}
		}
	}
}

if ($resultLines.Count -eq 0) {
	$resultLines += "$ScriptName`: [$env:COMPUTERNAME] No changes were made."
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

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.