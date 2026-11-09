# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes empty folders from a specified folder (add -Recurse to include all nested subfolders). There is also a list of ProtectedFolders that should be avoided at all costs, add to this list as you see fit.

# NOTE: Never run this against a Git repository, since folders inside .git (i.e. refs and hooks) are legitimately empty and deleting them can break the repository; use -Exclude to skip any folder that must not be touched

# NOTE2: Without -Recurse only the immediate subfolders of -Path are considered, so a folder that contains only empty subfolders is not deleted; with -Recurse the tree is processed deepest first, so those emptied parent folders are deleted as well

# NOTE3: Junctions and symbolic links are never followed or deleted, and a folder whose contents can't be read is skipped and reported instead of being treated as empty

# Optional flags:
#     -DeleteAll:            Automatically confirm deletion of all empty folders without prompting
#     -Exclude <TEXT>:       Skip folders (and everything inside them) whose names match these wildcard patterns, comma-separated (i.e. -Exclude .git,node_modules)
#     -NoConsoleOutput:      Suppress console output (requires -SaveResults and either -DeleteAll or -Preview)
#     -Path <PATH>:          Path to the folder to process (prompts if not specified)
#     -Preview:              Show which folders would be deleted without actually removing anything
#     -Recurse:              Also process all nested subfolders, deepest first (without it, only the immediate subfolders of -Path are considered)
#     -SaveResults <PATH>:   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Help / -?:            Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$DeleteAll,
	[string[]]$Exclude,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Preview,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-Exclude <TEXT>] [-NoConsoleOutput] [-Path <PATH>] [-Preview] [-Recurse] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll           Automatically confirm deletion of all empty folders without prompting" -ForegroundColor Cyan
	Write-Host "  -Exclude <TEXT>      Skip folders (and everything inside them) whose names match these wildcard patterns, comma-separated (i.e. -Exclude .git,node_modules)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults and either -DeleteAll or -Preview)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to the folder to process (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show which folders would be deleted without actually removing anything" -ForegroundColor Cyan
	Write-Host "  -Recurse             Also process all nested subfolders, deepest first (without it, only the immediate subfolders of -Path are considered)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
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
# The other paths are built from environment variables, so the list still works if Windows is installed on a different drive
$ProtectedFolders = @(
	# Windows system folders
	$env:ProgramData,
	"$env:USERPROFILE\AppData",
	$env:windir,
	# Program Files (64-bit)
	"$env:ProgramW6432\Common Files",
	"$env:ProgramW6432\ModifiableWindowsApps",
	"$env:ProgramW6432\Uninstall Information",
	"$env:ProgramW6432\WindowsApps",
	# Program Files (x86)
	"${env:ProgramFiles(x86)}\Common Files",
	"${env:ProgramFiles(x86)}\Uninstall Information",
	"${env:ProgramFiles(x86)}\WindowsApps"
)

# Returns true if a path is one of the protected folders or is inside one
$isProtected = {
	param($candidate)
	foreach ($protectedFolder in $ProtectedFolders) {
		if ($protectedFolder -and ($candidate.Equals($protectedFolder, [System.StringComparison]::OrdinalIgnoreCase) -or $candidate.StartsWith($protectedFolder + '\', [System.StringComparison]::OrdinalIgnoreCase))) {
			return $true
		}
	}
	return $false
}

# -NoConsoleOutput requires -SaveResults and either -DeleteAll or -Preview, since without one of those this script
# can still block on the delete confirmation prompt with no visible context if output is suppressed
if ($NoConsoleOutput -and (-not $SaveResults -or (-not $DeleteAll -and -not $Preview))) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults and either -DeleteAll or -Preview."
	exit 1
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

# Prompt user for the directory to process if not specified
if (-not $Path) {
	$Path = Read-Host "`nEnter the full path to the folder where empty folders should be deleted"
	if (-not $NoConsoleOutput) { Write-Host "" }
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
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

# Resolve the full path, since a relative path or a trailing backslash would otherwise break the protected folder and -Exclude checks below
$resolvedPath = (Get-Item -LiteralPath $Path).FullName

if (& $isProtected $resolvedPath.TrimEnd('\')) {
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

# Get all directories, sorted by depth (deepest first)
# This ensures empty subfolders are deleted before their parent folders
$folders = Get-ChildItem -LiteralPath $resolvedPath -Directory -Force -Recurse:$Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending

# Junctions and symbolic links are never followed or deleted; Windows PowerShell 5.1 can recurse into them, so anything reached through one is skipped too
$linkPaths = @($folders | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint } | ForEach-Object { $_.FullName })

$foldersDeleted = @()
$foldersSkipped = @()
$foldersFailed = @()
$foldersUnreadable = @()
$previewDeleted = @{}

foreach ($folder in $folders) {
	# Skip protected folders and their subfolders
	if (& $isProtected $folder.FullName) { continue }

	# Skip junctions and symbolic links, and anything reached through one
	$isLinked = $false
	foreach ($linkPath in $linkPaths) {
		if ($folder.FullName.Equals($linkPath, [System.StringComparison]::OrdinalIgnoreCase) -or $folder.FullName.StartsWith($linkPath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
			$isLinked = $true
			break
		}
	}
	if ($isLinked) { continue }

	# Skip folders (and everything inside them) with a name matching -Exclude
	if ($Exclude) {
		$isExcluded = $false
		foreach ($namePart in ($folder.FullName.Substring($resolvedPath.TrimEnd('\').Length).TrimStart('\') -split '\\')) {
			foreach ($excludePattern in $Exclude) {
				if ($namePart -like $excludePattern) { $isExcluded = $true }
			}
		}
		if ($isExcluded) { continue }
	}

	# Check if the folder is empty (contains no files or subfolders)
	# A folder whose contents can't be read is skipped and reported, since it would otherwise look empty
	try {
		$children = @(Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction Stop)
	}
	catch {
		$foldersUnreadable += $folder.FullName
		continue
	}

	# Nothing is deleted in Preview, so subfolders already listed as deletable are ignored here to show what a real run would remove once they are gone
	if ($Preview) {
		$children = @($children | Where-Object { -not $previewDeleted.ContainsKey($_.FullName) })
	}

	if ($children.Count -eq 0) {
		if ($Preview) {
			if (-not $NoConsoleOutput) { Write-Host "Would delete: $($folder.FullName)" -ForegroundColor Cyan }
			$previewDeleted[$folder.FullName] = $true
			$foldersDeleted += $folder.FullName
		}
		else {
			$shouldDelete = $DeleteAll

			if (-not $DeleteAll) {
				do {
					$confirm = Read-Host "Delete empty folder '$($folder.FullName)'? (Y/N)"
					if ($confirm -match '^[yYnN]$') {
						break
					}
					else {
						Write-Host "Invalid input. Please type Y or N." -ForegroundColor Yellow
					}
				} while ($true)

				$shouldDelete = $confirm -match '^[yY]$'
				if (-not $shouldDelete) {
					Write-Host "Skipped: $($folder.FullName)" -ForegroundColor Yellow
					$foldersSkipped += $folder.FullName
				}
			}

			if ($shouldDelete) {
				try {
					# Deliberately no -Recurse, so a folder that gained contents since the check above is not deleted along with them
					Remove-Item -LiteralPath $folder.FullName -Force -ErrorAction Stop
					$foldersDeleted += $folder.FullName
					if (-not $NoConsoleOutput) { Write-Host "Deleted: $($folder.FullName)" -ForegroundColor Green }
				}
				catch {
					$foldersFailed += "$($folder.FullName): $($_.Exception.Message)"
					if (-not $NoConsoleOutput) {
						Write-Host ""
						Write-Warning "Could not delete '$($folder.FullName)': $($_.Exception.Message)"
					}
				}
			}
		}
	}
}

$unreadableNote = ""
if ($foldersUnreadable.Count -gt 0) {
	$unreadableNote = " $($foldersUnreadable.Count) folder(s) could not be read and were skipped."
}

if ($Preview) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] $($foldersDeleted.Count) empty folder(s) would be deleted from '$Path'.$unreadableNote"
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $summaryLine -ForegroundColor Cyan
	}
}
elseif ($foldersFailed.Count -gt 0) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Deleted $($foldersDeleted.Count) empty folder(s) from '$Path', but $($foldersFailed.Count) could not be deleted.$unreadableNote"
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $summaryLine
	}
}
elseif ($foldersDeleted.Count -gt 0) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Successfully deleted $($foldersDeleted.Count) empty folder(s) from '$Path'.$unreadableNote"
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $summaryLine -ForegroundColor Green
	}
}
else {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] No folders were deleted from '$Path'.$unreadableNote"
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

		if ($foldersFailed.Count -gt 0) {
			$FileOutputLines += "Folders that could not be deleted:"
			foreach ($f in $foldersFailed) {
				$FileOutputLines += "  $f"
			}
			$FileOutputLines += ""
		}
	}

	if ($foldersUnreadable.Count -gt 0) {
		$FileOutputLines += "Folders that could not be read:"
		foreach ($f in $foldersUnreadable) {
			$FileOutputLines += "  $f"
		}
		$FileOutputLines += ""
	}

	$FileOutputLines += $summaryLine

	while ($FileOutputLines.Count -gt 0 -and $FileOutputLines[-1] -eq '') {
		$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
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

if ($foldersFailed.Count -gt 0) {
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.