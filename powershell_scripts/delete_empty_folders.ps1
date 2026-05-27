# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all empty folders from a user-specified folder. It prompts for the folder path and requires confirmation before deleting.
# Example usage with -WhatIf (preview deletions without actually removing anything):
# Remove-EmptyFolder -Path C:\PATH\TO\FOLDER -WhatIf
# Remove-EmptyFolder -Path \\PATH\TO\FOLDER -WhatIf

# Optional flags:
#     -DeleteAll: Automatically confirm deletion of all empty folders without prompting
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -WhatIf: Preview deletions without actually removing anything (built-in PowerShell parameter)
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false, SupportsShouldProcess=$true)]
param (
	[switch]$DeleteAll,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-SaveResults <PATH>] [-WhatIf] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll            Automatically confirm deletion of all empty folders without prompting" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -WhatIf              Preview deletions without actually removing anything (built-in PowerShell parameter)" -ForegroundColor Cyan
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

function Remove-EmptyFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)]
		[string]$Path
	)

	# Check if the specified folder exists
	if (-not (Test-Path -Path $Path -PathType Container)) {
		Write-Host ""
		Write-Error "The specified path '$Path' does not exist or is not a directory."
		return
	}

	# Get all directories, sorted by depth (deepest first)
	# This ensures empty subfolders are deleted before their parent folders
	$folders = Get-ChildItem -LiteralPath $Path -Directory -Recurse | Sort-Object FullName -Descending

	# Track deleted folders
	$foldersDeleted = @()
	$foldersSkipped = @()

	foreach ($folder in $folders) {
		# Check if the folder is empty (contains no files or subfolders)
		if (-not (Get-ChildItem -LiteralPath $folder.FullName -Recurse -Force | Select-Object -First 1)) {
			if ($DeleteAll) {
				# Skip confirmation and delete immediately
				if ($PSCmdlet.ShouldProcess($folder.FullName, "Remove empty folder")) {
					Write-Host "Deleting empty folder: $($folder.FullName)" -ForegroundColor Yellow
					Remove-Item -LiteralPath $folder.FullName -Recurse -Force
					$foldersDeleted += $folder.FullName
				}
			}
			else {
				# Prompt the user for confirmation and validate input
				do {
					$confirm = Read-Host "`nDelete empty folder '$($folder.FullName)'? (Y/N)"
					if ($confirm -match '^[yYnN]$') {
						break
					}
					else {
						Write-Host "Invalid input. Please type Y or N." -ForegroundColor Yellow
					}
				} while ($true)

				if ($confirm -match '^[yY]$') {
					if ($PSCmdlet.ShouldProcess($folder.FullName, "Remove empty folder")) {
						Write-Host "Deleting empty folder: $($folder.FullName)" -ForegroundColor Yellow
						Remove-Item -LiteralPath $folder.FullName -Recurse -Force
						$foldersDeleted += $folder.FullName
					}
				}
				else {
					Write-Host "Skipped folder: $($folder.FullName)" -ForegroundColor Cyan
					$foldersSkipped += $folder.FullName
				}
			}
		}
	}

	# Final summary with count
	if ($foldersDeleted.Count -gt 0) {
		Write-Host "`nSuccessfully deleted $($foldersDeleted.Count) confirmed empty folder(s) from '$Path'." -ForegroundColor Green
	}
	else {
		Write-Host "`nNo folders were deleted." -ForegroundColor Yellow
	}

	# Save results to text file if requested
	if ($SaveResults) {
		$FileOutputLines = @()

		if ($foldersDeleted.Count -gt 0) {
			$FileOutputLines += "Deleted folders:"
			foreach ($f in $foldersDeleted) {
				$FileOutputLines += "  $f"
			}
		}

		if ($foldersSkipped.Count -gt 0) {
			if ($FileOutputLines.Count -gt 0) { $FileOutputLines += "" }
			$FileOutputLines += "Skipped folders:"
			foreach ($f in $foldersSkipped) {
				$FileOutputLines += "  $f"
			}
		}

		$summaryLine = "Successfully deleted $($foldersDeleted.Count) confirmed empty folder(s) from '$Path'."
		if ($FileOutputLines.Count -gt 0) { $FileOutputLines += "" }
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
}

# Prompt the user for the directory to process
$deleteEmptyFolders = Read-Host "`nEnter the full path to the folder where empty folders should be deleted"

# Call the function
Remove-EmptyFolder -Path $deleteEmptyFolders -DeleteAll:$DeleteAll

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.