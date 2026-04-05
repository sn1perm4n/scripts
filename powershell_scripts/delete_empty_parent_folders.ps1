# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans a user-specified directory for empty parent folders and prompts the user for each deletion. There is also a list of ProtectedFolders that should be avoided at all costs, add to this list as you see fit.

function Remove-ParentEmptyFolderStrict {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)]
		[string]$Path
	)

	# Dummy ShouldProcess call to satisfy PSScriptAnalyzer
	$null = $PSCmdlet.ShouldProcess('dummy') 2>$null

	# List of critical/protected folders to skip. Do not allow scanning of protected folders. Immediately stop execution if the user selects a critical/protected folder.
	$ProtectedFolders = @(
		# Windows system folders
		"C:\ProgramData",
		"C:\Users\reedwaller\AppData"
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

	if ($ProtectedFolders | Where-Object { $folderToScan -ieq $_ }) {
		Write-Host "`nWARNING: The folder '$folderToScan' is protected and cannot be scanned." -ForegroundColor Yellow
		return
	}

	# Validate the path
	if (-not (Test-Path -Path $Path -PathType Container)) {
		Write-Host "`nThe specified path '$Path' does not exist or is not a directory." -ForegroundColor Red
		return
	}

	# Get all directories recursively
	$folders = Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue

	# Compute depth and sort: deepest first, siblings alphabetically
	$folders = $folders |
		Select-Object *, @{Name='Depth';Expression={($_.FullName.Split('\').Count)}} |
		Sort-Object -Property @{Expression='Depth';Descending=$true}, @{Expression='FullName';Descending=$false}

	$deletedFolders = @()

	foreach ($folder in $folders) {

		# Skip protected folders and their subfolders
		if ($ProtectedFolders | Where-Object { $folder.FullName -ieq $_ -or $folder.FullName -like "$_\*" }) {
			continue
		}

		# Check if folder contains any files or subfolders
		$children = Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction SilentlyContinue
		if (-not $children) {

			Write-Host "`nDelete empty folder '$($folder.FullName)'? (Y/N)" -ForegroundColor Cyan
			$response = Read-Host

			if ($response -match '^[Yy]$') {
				Remove-Item -LiteralPath $folder.FullName -Force
				$deletedFolders += $folder.FullName
				Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green
			}
			else {
				Write-Host "Skipped: $($folder.FullName)" -ForegroundColor Yellow
			}
		}
	}

	# Output summary of folders that would be deleted
	if ($deletedFolders.Count -gt 0) {
		Write-Host "`nDeleted folders:"
		$deletedFolders | Sort-Object | ForEach-Object { Write-Host $_ }
		Write-Host "`nTotal: $($deletedFolders.Count) folder(s) deleted." -ForegroundColor Green
	}
	else {
		Write-Host "`nNo folders were deleted." -ForegroundColor Yellow
	}
}

# Prompt user for the folder to scan
$folderToScan = Read-Host "`nEnter the full path of the folder you want to scan"

# Run the function
Remove-ParentEmptyFolderStrict -Path $folderToScan

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.