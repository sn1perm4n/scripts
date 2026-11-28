# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# Deletes the contents of a specified folder and can be reused for any folder

# Optional flags:
#     -DeleteAll:          Automatically delete all contents without prompting
#     -Exclude <TEXT>:     Skip files or folders (and everything inside them) whose names match these wildcard patterns, comma-separated (i.e. -Exclude "keep_*,archive")
#     -Filter <TEXT>:      Only delete files whose names match these wildcard patterns, comma-separated (i.e. -Filter "*.log,*.tmp"; leaves folders in place)
#     -NoConsoleOutput:    Suppress console output (requires -DeleteAll, -Path, and -SaveResults)
#     -OlderThan <N>:      Only delete files last modified more than this many days ago (leaves folders in place)
#     -Path <PATH>:        Full path to the folder to clean (prompts if not specified)
#     -Preview:            Show what would be deleted without making any changes
#     -SaveResults <PATH>: Save results to a text file (overwrites if file exists, with a hostname header identifying the machine the script was run from)
#     -Help / -?:          Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$DeleteAll,
	[string[]]$Exclude,
	[string[]]$Filter,
	[switch]$NoConsoleOutput,
	[ValidateRange(1, [int]::MaxValue)]
	[int]$OlderThan,
	[string]$Path,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-DeleteAll] [-Exclude <TEXT>] [-Filter <TEXT>] [-NoConsoleOutput] [-OlderThan <N>] [-Path <PATH>] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -DeleteAll           Automatically delete all contents without prompting" -ForegroundColor Cyan
	Write-Host "  -Exclude <TEXT>      Skip files or folders (and everything inside them) whose names match these wildcard patterns, comma-separated (i.e. -Exclude `"keep_*,archive`")" -ForegroundColor Cyan
	Write-Host "  -Filter <TEXT>       Only delete files whose names match these wildcard patterns, comma-separated (i.e. -Filter `"*.log,*.tmp`"; leaves folders in place)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -DeleteAll, -Path, and -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -OlderThan <N>       Only delete files last modified more than this many days ago (leaves folders in place)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Full path to the folder to clean (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Preview             Show what would be deleted without making any changes" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (overwrites if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Normalize -Exclude and -Filter so a single comma-separated string works the same as multiple values
if ($Exclude) {
	$Exclude = $Exclude | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}
if ($Filter) {
	$Filter = $Filter | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Resolve -SaveResults against the current PowerShell location, since the .NET file methods used below resolve relative paths against the process working directory instead
if ($SaveResults) {
	$SaveResults = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SaveResults)
}

# Validate -SaveResults path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path -LiteralPath $saveDir)) {
		Write-Host ""
		Write-Error "$ScriptName`: The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# -NoConsoleOutput requires -DeleteAll, -Path, and -SaveResults, since without -DeleteAll this script
# can still block on the delete confirmation prompt with no visible context if output is suppressed, and without -Path it would prompt for the folder
if ($NoConsoleOutput -and (-not $DeleteAll -or -not $Path -or -not $SaveResults)) {
	Write-Host ""
	Write-Error "$ScriptName`: -NoConsoleOutput requires -DeleteAll, -Path, and -SaveResults."
	exit 1
}

# Prompt for the folder if -Path was not specified
if (-not $Path) {
	$Path = (Read-Host "`nEnter the full path to the folder to clean").Trim().Trim('"')
	if (-not $Path) {
		Write-Host ""
		Write-Error "$ScriptName`: No folder path was provided."
		exit 1
	}
}

# Refuse drive roots and core system folders, since deleting their contents could make Windows unusable
$resolvedTarget = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path).TrimEnd('\')
$protectedFolders = @($env:SystemDrive, $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:USERPROFILE, (Split-Path $env:USERPROFILE -Parent)) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
if ($resolvedTarget -match '^[A-Za-z]:?$' -or $resolvedTarget -in $protectedFolders) {
	Write-Host ""
	Write-Error "$ScriptName`: Refusing to clean a drive root or core system folder: '$resolvedTarget'"
	exit 1
}

$FileOutputLines = @("$env:COMPUTERNAME`:")

if (-not $NoConsoleOutput) { Write-Host "`nChecking '$Path'..." -ForegroundColor Cyan }

# A path that is not a folder (i.e. a file) is treated as missing, since Get-ChildItem would otherwise list that single file and it would be deleted
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
	$warningMessage = "The directory '$Path' does not exist."
	if (Test-Path -LiteralPath $Path -PathType Leaf) {
		$warningMessage = "'$Path' is a file, not a folder. To delete a single file, use its folder as -Path with -Filter (i.e. -Filter `"$(Split-Path $Path -Leaf)`")."
	}
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $warningMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, "$env:COMPUTERNAME`:`n$warningMessage")
			if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

$failedCount = 0

try {
	# List everything inside the folder, collecting read errors (i.e. access denied) so they are reported instead of printing as uncaught errors
	$allItems = @(Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable readErrors)

	if ($allItems.Count -eq 0 -and $readErrors.Count -eq 0) {
		$warningMessage = "The directory '$Path' exists but is empty."
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $warningMessage
		}
		if ($SaveResults) {
			try {
				[System.IO.File]::WriteAllText($SaveResults, "$env:COMPUTERNAME`:`n$warningMessage")
				if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
			}
			catch {
				Write-Host ""
				Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
			}
		}
		exit 0
	}

	# Report items that could not be read, since they are left in place and count as failures
	foreach ($readError in $readErrors) {
		$readMessage = "Could not read '$($readError.TargetObject)': $($readError.Exception.Message)"
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $readMessage
		}
		if ($SaveResults) { $FileOutputLines += $readMessage }
		$failedCount++
	}

	# Decide which items to delete: -Exclude skips matching files or folders (and everything inside them), -Filter limits deletion to files with matching names, and -OlderThan limits deletion to files older than the cutoff
	$rootFullPath = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')
	$cutoffDate = if ($OlderThan -gt 0) { (Get-Date).AddDays(-$OlderThan) } else { $null }
	$items = @()
	$skippedItems = @()
	foreach ($candidate in $allItems) {
		$skip = $false
		if ($Exclude) {
			$relativePath = $candidate.FullName.Substring($rootFullPath.Length).TrimStart('\', '/')
			foreach ($pattern in $Exclude) {
				foreach ($part in @($relativePath -split '[\\/]')) {
					if ($part -like $pattern) { $skip = $true }
				}
			}
		}
		if ($Filter -and ($candidate.PSIsContainer -or -not ($Filter | Where-Object { $candidate.Name -like $_ }))) { $skip = $true }
		if ($cutoffDate -and ($candidate.PSIsContainer -or $candidate.LastWriteTime -ge $cutoffDate)) { $skip = $true }
		if ($skip) { $skippedItems += $candidate } else { $items += $candidate }
	}

	# A folder that still contains a skipped item has to stay, so remove it from the delete list too
	if ($skippedItems.Count -gt 0) {
		$keepFolders = @{}
		foreach ($skippedItem in $skippedItems) {
			$parentPath = Split-Path $skippedItem.FullName -Parent
			while ($parentPath.Length -gt $rootFullPath.Length -and -not $keepFolders.ContainsKey($parentPath)) {
				$keepFolders[$parentPath] = $true
				$parentPath = Split-Path $parentPath -Parent
			}
		}
		$items = @($items | Where-Object { -not ($_.PSIsContainer -and $keepFolders.ContainsKey($_.FullName)) })
	}

	if ($items.Count -eq 0) {
		$warningMessage = "The directory '$Path' has no items to delete after applying -Exclude, -Filter, and -OlderThan."
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $warningMessage
		}
		if ($SaveResults) {
			try {
				[System.IO.File]::WriteAllText($SaveResults, "$env:COMPUTERNAME`:`n$warningMessage")
				if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
			}
			catch {
				Write-Host ""
				Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
			}
		}
		exit $(if ($failedCount -gt 0) { 1 } else { 0 })
	}

	# Calculate size before deletion
	$totalBytesFreed = ($items | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
	if (-not $totalBytesFreed) { $totalBytesFreed = 0 }

	if (-not $NoConsoleOutput) { Write-Host "`nThe following items will be deleted from '$Path':" -ForegroundColor Cyan }
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
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. $freedDisplay would be freed."
		if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Cyan }
		if ($SaveResults) { $FileOutputLines += ""; $FileOutputLines += $summaryLine }
	}
	else {
		# User confirmation unless -DeleteAll is specified
		if ($DeleteAll) {
			$userInput = 'Y'
		}
		else {
			$confirmTarget = if ($Exclude -or $Filter -or $OlderThan -gt 0) { 'the items listed above' } else { 'all contents' }
			$userInput = Read-Host "`nAre you sure you want to delete $($confirmTarget)? (Y/N)"
		}

		if ($userInput -notmatch '^[Yy]$') {
			$warningMessage = "$ScriptName`: Operation cancelled by user."
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning $warningMessage
			}
			if ($SaveResults) {
				try {
					[System.IO.File]::WriteAllText($SaveResults, "$env:COMPUTERNAME`:`n$warningMessage")
					if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green }
				}
				catch {
					Write-Host ""
					Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
				}
			}
			exit 0
		}

		# Delete deepest items first so folders are already empty when reached, and count failures instead of assuming success
		$deletedCount = 0
		foreach ($item in ($items | Sort-Object { $_.FullName.Length } -Descending)) {
			try {
				# A folder that still contains something (i.e. a child that could not be deleted) is left in place, since Remove-Item would prompt for confirmation instead of failing
				if ($item.PSIsContainer -and (Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
					continue
				}
				Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
				$deletedCount++
			}
			catch {
				$failedCount++
				if (-not $NoConsoleOutput) {
					Write-Host ""
					Write-Warning "Could not delete '$($item.FullName)': $($_.Exception.Message)"
				}
				if ($SaveResults) { $FileOutputLines += "Could not delete '$($item.FullName)': $($_.Exception.Message)" }
			}
		}

		if ($failedCount -gt 0) {
			$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Cleanup finished with errors, $deletedCount item(s) deleted, $failedCount could not be deleted."
			if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Yellow }
		}
		else {
			$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Cleanup complete, $freedDisplay freed."
			if (-not $NoConsoleOutput) { Write-Host "`n$summaryLine" -ForegroundColor Green }
		}
		if ($SaveResults) { $FileOutputLines += ""; $FileOutputLines += $summaryLine }
	}
}
catch {
	$errorMessage = "$ScriptName`: An error occurred while trying to delete items in '$Path': $($_.Exception.Message)"
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
		$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
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

if ($failedCount -gt 0) {
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.