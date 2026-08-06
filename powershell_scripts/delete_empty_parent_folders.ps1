# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans a specified directory for empty parent folders and can prompt for each deletion. There is also a list of ProtectedFolders that should be avoided at all costs, add to this list as you see fit.

# Optional flags:
#     -DeleteAll: Automatically confirm deletion of all empty folders without prompting
#     -NoConsoleOutput: Suppress console output (requires -DeleteAll and -SaveResults)
#     -Path <PATH>: Path to the folder to scan (prompts if not specified)
#     -Preview: Show which folders would be deleted without actually removing anything
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

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
	Write-Host "  -Path <PATH>         Path to the folder to scan (prompts if not specified)" -ForegroundColor Cyan
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

# -NoConsoleOutput requires -DeleteAll and -SaveResults, since without -DeleteAll this script
# can still block on the delete confirmation prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $DeleteAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -DeleteAll and -SaveResults."
	exit 1
}

# Prompt user for the folder to scan if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path of the folder you want to scan"
	if (-not $NoConsoleOutput) { Write-Host "" }
}

if ($ProtectedFolders | Where-Object { $Path -ieq $_ }) {
	$errorMessage = "The folder '$Path' is protected and cannot be scanned."
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

# Get all directories recursively
# Compute depth and sort: deepest first, siblings alphabetically
$folders = Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
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
		if ($Preview) {
			if (-not $NoConsoleOutput) { Write-Host "Would delete: $($folder.FullName)" -ForegroundColor Cyan }
			$deletedFolders += $folder.FullName
		}
		elseif ($DeleteAll) {
			Remove-Item -LiteralPath $folder.FullName -Force
			$deletedFolders += $folder.FullName
			if (-not $NoConsoleOutput) { Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green }
		}
		else {
			Write-Host "Delete empty folder '$($folder.FullName)'? (Y/N)" -ForegroundColor Cyan
			$response = Read-Host

			if ($response -match '^[Yy]$') {
				Remove-Item -LiteralPath $folder.FullName -Force
				$deletedFolders += $folder.FullName
				Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green
			}
			else {
				Write-Host "Skipped: $($folder.FullName)" -ForegroundColor Yellow
				$skippedFolders += $folder.FullName
			}
		}
	}
}

if ($Preview) {
	$summaryLine = "$ScriptName`: $($deletedFolders.Count) empty folder(s) would be deleted from '$Path'."
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $summaryLine -ForegroundColor Cyan
	}
}
elseif ($deletedFolders.Count -gt 0) {
	$summaryLine = "$ScriptName`: Successfully deleted $($deletedFolders.Count) empty folder(s) from '$Path'."
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
		if ($deletedFolders.Count -gt 0) {
			$FileOutputLines += "Folders that would be deleted:"
			foreach ($f in $deletedFolders) {
				$FileOutputLines += "  $f"
			}
			$FileOutputLines += ""
		}
	}
	else {
		if ($deletedFolders.Count -gt 0) {
			$FileOutputLines += "Deleted folders:"
			foreach ($f in $deletedFolders) {
				$FileOutputLines += "  $f"
			}
			$FileOutputLines += ""
		}

		if ($skippedFolders.Count -gt 0) {
			$FileOutputLines += "Skipped folders:"
			foreach ($f in $skippedFolders) {
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