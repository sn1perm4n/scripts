# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans a user-specified directory for empty parent folders and prompts the user for each deletion. There is also a list of ProtectedFolders that should be avoided at all costs, add to this list as you see fit.

# Optional flags:
#     -DeleteAll: Automatically confirm deletion of all empty folders without prompting
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -WhatIf: Preview deletions without actually removing anything (built-in PowerShell parameter)
#     -Help / -?: Display this help message

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
	Write-Host "  -DeleteAll           Automatically confirm deletion of all empty folders without prompting" -ForegroundColor Cyan
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

function Remove-ParentEmptyFolderStrict {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[Parameter(Mandatory=$true)]
		[string]$FolderToScan
	)

	# List of critical/protected folders to skip. Do not allow scanning of protected folders. Immediately stop execution if the user selects a critical/protected folder.
	# $env:USERPROFILE\AppData resolves to C:\Users\<username>\AppData
	$ProtectedFolders = @(
		# Windows system folders
		"C:\ProgramData",
		"$env:USERPROFILE\AppData",
		"C:\Windows",
		# Program Files (64-bit)
		"C:\Program Files\Common Files",
		"C:\Program Files\ModifiableWindowsApps",
		"C:\Program Files\Uninstall Information",
		"C:\Program Files\WindowsApps",
		# Program Files (x86)
		"C:\Program Files (x86)\Common Files",
		"C:\Program Files (x86)\Uninstall Information",
		"C:\Program Files (x86)\WindowsApps"
	)

	if ($ProtectedFolders | Where-Object { $FolderToScan -ieq $_ }) {
		Write-Host "`nWARNING: The folder '$FolderToScan' is protected and cannot be scanned." -ForegroundColor Yellow
		return
	}

	# Validate the path
	if (-not (Test-Path -Path $Path -PathType Container)) {
		Write-Host ""
		Write-Error "The specified path '$Path' does not exist or is not a directory."
		return
	}

	# Get all directories recursively
	$folders = Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue

	# Compute depth and sort: deepest first, siblings alphabetically
	$folders = $folders |
		Select-Object *, @{Name='Depth';Expression={($_.FullName.Split('\').Count)}} |
		Sort-Object -Property @{Expression='Depth';Descending=$true}, @{Expression='FullName';Descending=$false}

	$deletedFolders = @()
	$skippedFolders = @()

	foreach ($folder in $folders) {
		# Skip protected folders and their subfolders
		if ($ProtectedFolders | Where-Object { $folder.FullName -ieq $_ -or $folder.FullName -like "$_\*" }) {
			continue
		}

		# Check if folder contains any files or subfolders
		$children = Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction SilentlyContinue

		if (-not $children) {
			if ($DeleteAll) {
				if ($PSCmdlet.ShouldProcess($folder.FullName, "Remove empty folder")) {
					Remove-Item -LiteralPath $folder.FullName -Force
					$deletedFolders += $folder.FullName
					Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green
				}
			}
			else {
				Write-Host "`nDelete empty folder '$($folder.FullName)'? (Y/N)" -ForegroundColor Cyan
				$response = Read-Host

				if ($response -match '^[Yy]$') {
					if ($PSCmdlet.ShouldProcess($folder.FullName, "Remove empty folder")) {
						Remove-Item -LiteralPath $folder.FullName -Force
						$deletedFolders += $folder.FullName
						Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green
					}
				}
				else {
					Write-Host "Skipped: $($folder.FullName)" -ForegroundColor Yellow
					$skippedFolders += $folder.FullName
				}
			}
		}
	}

	# Final summary with count
	if ($deletedFolders.Count -gt 0) {
		Write-Host "`nSuccessfully deleted $($deletedFolders.Count) confirmed empty folder(s) from '$Path'." -ForegroundColor Green
	}
	else {
		Write-Host "`nNo folders were deleted." -ForegroundColor Yellow
	}

	# Save results to text file if requested
	if ($SaveResults) {
		$FileOutputLines = @()

		if ($deletedFolders.Count -gt 0) {
			$FileOutputLines += "Deleted folders:"
			foreach ($f in $deletedFolders) {
				$FileOutputLines += "  $f"
			}
		}

		if ($skippedFolders.Count -gt 0) {
			if ($FileOutputLines.Count -gt 0) { $FileOutputLines += "" }
			$FileOutputLines += "Skipped folders:"
			foreach ($f in $skippedFolders) {
				$FileOutputLines += "  $f"
			}
		}

		$summaryLine = "Successfully deleted $($deletedFolders.Count) confirmed empty folder(s) from '$Path'."
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

# Prompt user for the folder to scan
$folderToScan = Read-Host "`nEnter the full path of the folder you want to scan"

# Call the function
Remove-ParentEmptyFolderStrict -Path $folderToScan -FolderToScan $folderToScan -DeleteAll:$DeleteAll

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.