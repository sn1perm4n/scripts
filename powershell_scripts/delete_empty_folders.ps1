# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes all empty folders from a user-specified folder. It prompts for the folder path and requires confirmation before deleting.
# Example usage with -WhatIf (preview deletions without actually removing anything):
# Remove-EmptyFolder -Path C:\PATH\TO\FOLDER -WhatIf
# Remove-EmptyFolder -Path \\PATH\TO\FOLDER -WhatIf
# The script will still prompt for Y/N confirmation for each empty folder when -WhatIf is not used

#Requires -RunAsAdministrator

function Remove-EmptyFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)]
		[string]$Path
	)

	# Check if the specified folder exists
	if (-not (Test-Path -Path $Path -PathType Container)) {
		Write-Host "`nThe specified path '$Path' does not exist or is not a directory." -ForegroundColor Red
		return
	}

	# Get all directories, sorted by depth (deepest first)
	# This ensures empty subfolders are deleted before their parent folders
	$folders = Get-ChildItem -LiteralPath $Path -Directory -Recurse | Sort-Object FullName -Descending

	# Track deleted folders
	$foldersDeleted = @()

	foreach ($folder in $folders) {
		# Check if the folder is empty (contains no files or subfolders)
		if (-not (Get-ChildItem -LiteralPath $folder.FullName -Recurse -Force | Select-Object -First 1)) {

			# Prompt the user for confirmation and validate input
			do {
				$confirm = Read-Host "`nDelete empty folder '$($folder.FullName)'? (Y/N)"
				if ($confirm -match '^[yYnN]$') {
					break
				} else {
					Write-Host "Invalid input. Please type Y or N." -ForegroundColor Yellow
				}
			} while ($true)

			if ($confirm -match '^[yY]$') {
				if ($PSCmdlet.ShouldProcess($folder.FullName, "Remove empty folder")) {
					Write-Host "Deleting empty folder: $($folder.FullName)" -ForegroundColor Yellow
					Remove-Item -LiteralPath $folder.FullName -Recurse -Force
					$foldersDeleted += $folder.FullName
				}
			} else {
				Write-Host "Skipped folder: $($folder.FullName)" -ForegroundColor Cyan
			}
		}
	}

	# Final summary with count
	if ($foldersDeleted.Count -gt 0) {
		Write-Host "`nSuccessfully deleted $($foldersDeleted.Count) confirmed empty folder(s) from '$Path'." -ForegroundColor Green
	} else {
		Write-Host "`nNo folders were deleted." -ForegroundColor Yellow
	}
}

# Prompt the user for the directory to process
$deleteEmptyFolders = Read-Host "`nEnter the full path to the folder where empty folders should be deleted"

# Call the function
Remove-EmptyFolder -Path $deleteEmptyFolders

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.