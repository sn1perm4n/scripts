# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script is a parameterized utility that deletes the contents of a specified folder. It can be reused for any folder:
# Usage: .\clean_folder.ps1 -TargetFolder "C:\ProgramData\Apple Computer\Installer Cache"

# Required flag:
#     -TargetFolder <PATH>: Full path to the folder to clean
# Optional flags:
#     -DeleteAll: Automatically delete all contents without prompting
#     -NoConsoleOutput: Suppress console output (requires -DeleteAll and -SaveResults)
#     -Preview: Show what would be deleted without making any changes
#     -Recurse: Include files in subdirectories when listing and deleting
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Help / -?: Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[Parameter(Mandatory=$true)]
	[string]$TargetFolder,
	[switch]$DeleteAll,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName -TargetFolder <PATH> [-DeleteAll] [-NoConsoleOutput] [-Preview] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nRequired:" -ForegroundColor Cyan
	Write-Host "  -TargetFolder <PATH>  Full path to the folder to clean" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll            Automatically delete all contents without prompting" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput      Suppress console output (requires -DeleteAll and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview              Show what would be deleted without making any changes" -ForegroundColor Cyan
	Write-Host "  -Recurse              Include files in subdirectories when listing and deleting" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>   Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
	Write-Host "  -Help                 Display this help message" -ForegroundColor Cyan
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

# -NoConsoleOutput requires -DeleteAll and -SaveResults, since without -DeleteAll this script
# can still block on the delete confirmation prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $DeleteAll -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -DeleteAll and -SaveResults."
	exit 1
}

$FileOutputLines = @()

if (-not $NoConsoleOutput) { Write-Host "`nChecking '$TargetFolder'..." -ForegroundColor Cyan }

if (-not (Test-Path -Path $TargetFolder)) {
	$warningMessage = "The directory '$TargetFolder' does not exist."
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

try {
	$items = Get-ChildItem -Path $TargetFolder -Force -Recurse:$Recurse

	if ($items.Count -eq 0) {
		$warningMessage = "The directory '$TargetFolder' exists but is empty."
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

	# Calculate size before deletion
	$totalBytesFreed = (Get-ChildItem -Path $TargetFolder -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
	if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

	if (-not $NoConsoleOutput) { Write-Host "`nThe following items will be deleted from '$TargetFolder':" -ForegroundColor Cyan }
	$items | ForEach-Object {
		if (-not $NoConsoleOutput) { Write-Host " - $($_.FullName)" }
		if ($SaveResults) { $FileOutputLines += " - $($_.FullName)" }
	}

	$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
	$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
	$freedDisplay = if ($totalBytesFreed -ge 1GB) {
		"$totalFreedGB GB"
	}
	else {
		"$totalFreedMB MB"
	}

	if ($Preview) {
		$summaryLine = "$ScriptName`: Preview complete. $freedDisplay would be freed."
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Cyan }
		if ($SaveResults) { $FileOutputLines += ""; $FileOutputLines += $summaryLine }
	}
	else {
		# User confirmation unless -DeleteAll is specified
		if ($DeleteAll) {
			$userInput = 'Y'
		}
		else {
			$userInput = Read-Host "`nAre you sure you want to delete all contents? (Y/N)"
		}

		if ($userInput -notmatch '^[Yy]$') {
			$warningMessage = "$ScriptName`: Operation cancelled by user."
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

		# Delete all files and folders
		$items | Remove-Item -Recurse -Force

		$summaryLine = "$ScriptName`: Cleanup complete, $freedDisplay freed."
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
		if ($SaveResults) { $FileOutputLines += ""; $FileOutputLines += $summaryLine }
	}
}
catch {
	$errorMessage = "An error occurred while trying to delete items in '$TargetFolder': $($_.Exception.Message)"
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