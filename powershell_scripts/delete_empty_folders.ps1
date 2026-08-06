# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all empty folders from a specified folder

# Optional flags:
#     -DeleteAll: Automatically confirm deletion of all empty folders without prompting
#     -NoConsoleOutput: Suppress console output (requires -DeleteAll and -SaveResults)
#     -Path <PATH>: Path to the folder to process (prompts if not specified)
#     -Preview: Show which folders would be deleted without actually removing anything
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$DeleteAll,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-NoConsoleOutput] [-Path <PATH>] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll           Automatically confirm deletion of all empty folders without prompting" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -DeleteAll and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to the folder to process (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show which folders would be deleted without actually removing anything" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""
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

# -NoConsoleOutput requires -DeleteAll and -SaveResults, since without -DeleteAll this script
# can still block on the delete confirmation prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $DeleteAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -DeleteAll and -SaveResults."
	exit 1
}

# Prompt user for the directory to process if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to the folder where empty folders should be deleted"
	if (-not $NoConsoleOutput) { Write-Host "" }
}

if (-not (Test-Path -Path $Path -PathType Container)) {
	$errorMessage = "The specified path '$Path' does not exist or is not a directory."
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

# Get all directories, sorted by depth (deepest first)
# This ensures empty subfolders are deleted before their parent folders
$folders = Get-ChildItem -LiteralPath $Path -Directory -Recurse | Sort-Object FullName -Descending

$foldersDeleted = @()
$foldersSkipped = @()

foreach ($folder in $folders) {
	# Check if the folder is empty (contains no files or subfolders)
	if (-not (Get-ChildItem -LiteralPath $folder.FullName -Recurse -Force | Select-Object -First 1)) {
		if ($Preview) {
			if (-not $NoConsoleOutput) { Write-Host "Would delete: $($folder.FullName)" -ForegroundColor Cyan }
			$foldersDeleted += $folder.FullName
		}
		elseif ($DeleteAll) {
			Remove-Item -LiteralPath $folder.FullName -Recurse -Force
			$foldersDeleted += $folder.FullName
			if (-not $NoConsoleOutput) { Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green }
		}
		else {
			do {
				$confirm = Read-Host "Delete empty folder '$($folder.FullName)'? (Y/N)"
				if ($confirm -match '^[yYnN]$') {
					break
				}
				else {
					Write-Host "Invalid input. Please type Y or N." -ForegroundColor Yellow
				}
			} while ($true)

			if ($confirm -match '^[yY]$') {
				Remove-Item -LiteralPath $folder.FullName -Recurse -Force
				$foldersDeleted += $folder.FullName
				Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green
			}
			else {
				Write-Host "Skipped: $($folder.FullName)" -ForegroundColor Yellow
				$foldersSkipped += $folder.FullName
			}
		}
	}
}

if ($Preview) {
	$summaryLine = "$ScriptName`: $($foldersDeleted.Count) empty folder(s) would be deleted from '$Path'."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $summaryLine -ForegroundColor Cyan
	}
}
elseif ($foldersDeleted.Count -gt 0) {
	$summaryLine = "$ScriptName`: Successfully deleted $($foldersDeleted.Count) empty folder(s) from '$Path'."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $summaryLine -ForegroundColor Green
	}
}
else {
	$summaryLine = "$ScriptName`: No folders were deleted from '$Path'."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $summaryLine
	}
}

# Save results to text file if requested
if ($SaveResults) {
	$FileOutputLines = @()

	if ($Preview) {
		if ($foldersDeleted.Count -gt 0) {
			$FileOutputLines += "Folders that would be deleted:"
			foreach ($f in $foldersDeleted) {
				$FileOutputLines += "  $f"
			}
			$FileOutputLines += ""
		}
	}
	else {
		if ($foldersDeleted.Count -gt 0) {
			$FileOutputLines += "Deleted folders:"
			foreach ($f in $foldersDeleted) {
				$FileOutputLines += "  $f"
			}
			$FileOutputLines += ""
		}

		if ($foldersSkipped.Count -gt 0) {
			$FileOutputLines += "Skipped folders:"
			foreach ($f in $foldersSkipped) {
				$FileOutputLines += "  $f"
			}
			$FileOutputLines += ""
		}
	}

	$FileOutputLines += $summaryLine

	while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	try {
		$outputString = ($FileOutputLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to: $SaveResults" -ForegroundColor Green }
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