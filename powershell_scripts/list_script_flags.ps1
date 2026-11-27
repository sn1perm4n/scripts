# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans PowerShell scripts and lists all flags defined in their param blocks (or, with -NoFlags, the scripts that define none)

# Optional flags:
#     -Align:                 Align flag descriptions into two columns when used with -Description (console output only)
#     -Count:                 Show the number of scripts each flag appears in (only meaningful with -Unique)
#     -Description:           Include flag descriptions from the # Optional flags comment block
#     -Exclude <TEXT>:        Skip scripts or folders (and everything inside them) whose names match these wildcard patterns, comma-separated (i.e. -Exclude "toggle_*,powershell_scripts_archive")
#     -Filenames:             Print only script names with no flag details or blank lines between entries
#     -Filter <TEXT>:         Only process scripts whose file names (with or without .ps1) match these wildcard patterns, comma-separated (i.e. -Filter "toggle_*,clean_*")
#     -FlagFilter <NAME,...>: Filter output to only scripts containing all specified flags (comma-separated, i.e. -FlagFilter "-SaveResults,-NoConsoleOutput")
#     -Missing:               Show scripts missing at least one flag specified via -FlagFilter, instead of scripts containing all of them (requires -FlagFilter)
#     -NoConsoleOutput:       Suppress console output (requires -SaveResults)
#     -NoFlags:               List scripts that declare no flags, plus any with an # Optional flags comment block but no param block flags, instead of listing flags (not supported with -Unique or -FlagFilter)
#     -Path <PATH>:           Path to a PowerShell script (.ps1) or folder (prompts if not specified)
#     -Recurse:               Search subdirectories recursively
#     -SaveResults <PATH>:    Save results to a .csv file (appends if file exists)
#     -Unique:                Show only unique deduplicated flags in an alphabetized list (a flag with different hints in different scripts is listed once per form, i.e. -Backup and -Backup <PATH>)
#     -Help / -?:             Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Align,
	[switch]$Count,
	[switch]$Description,
	[string[]]$Exclude,
	[switch]$Filenames,
	[string[]]$Filter,
	[string[]]$FlagFilter,
	[switch]$Missing,
	[switch]$NoConsoleOutput,
	[switch]$NoFlags,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Unique,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Align] [-Count] [-Description] [-Exclude <TEXT>] [-Filenames] [-Filter <TEXT>] [-FlagFilter <NAME,...>] [-Missing] [-NoConsoleOutput] [-NoFlags] [-Path <PATH>] [-Recurse] [-SaveResults <PATH>] [-Unique] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Align                  Align flag descriptions into two columns when used with -Description (console output only)" -ForegroundColor Cyan
	Write-Host "  -Count                  Show the number of scripts each flag appears in (only meaningful with -Unique)" -ForegroundColor Cyan
	Write-Host "  -Description            Include flag descriptions from the # Optional flags comment block" -ForegroundColor Cyan
	Write-Host "  -Exclude <TEXT>         Skip scripts or folders (and everything inside them) whose names match these wildcard patterns, comma-separated (i.e. -Exclude `"toggle_*,powershell_scripts_archive`")" -ForegroundColor Cyan
	Write-Host "  -Filenames              Print only script names with no flag details or blank lines between entries" -ForegroundColor Cyan
	Write-Host "  -Filter <TEXT>          Only process scripts whose file names (with or without .ps1) match these wildcard patterns, comma-separated (i.e. -Filter `"toggle_*,clean_*`")" -ForegroundColor Cyan
	Write-Host "  -FlagFilter <NAME,...>  Filter output to only scripts containing all specified flags (comma-separated, i.e. -FlagFilter `"-SaveResults,-NoConsoleOutput`")" -ForegroundColor Cyan
	Write-Host "  -Missing                Show scripts missing at least one flag specified via -FlagFilter, instead of scripts containing all of them (requires -FlagFilter)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput        Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -NoFlags                List scripts that declare no flags, plus any with an # Optional flags comment block but no param block flags, instead of listing flags (not supported with -Unique or -FlagFilter)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>            Path to a PowerShell script (.ps1) or folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse                Search subdirectories recursively" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>     Save results to a .csv file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Unique                 Show only unique deduplicated flags in an alphabetized list (a flag with different hints in different scripts is listed once per form, i.e. -Backup and -Backup <PATH>)" -ForegroundColor Cyan
	Write-Host "  -Help                   Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Normalize -FlagFilter so a single comma-separated string works the same as multiple values
if ($FlagFilter) {
	$FlagFilter = $FlagFilter | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Normalize -Filter and -Exclude so a single comma-separated string works the same as multiple values
if ($Filter) {
	$Filter = $Filter | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}
if ($Exclude) {
	$Exclude = $Exclude | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Warn on unsupported flag combinations
if ($Description -and $Unique) {
	Write-Host ""
	Write-Error "$ScriptName`: -Description is not supported with -Unique. Descriptions may vary per script and would be misleading in deduplicated output. Run without -Unique to see descriptions per script."
	exit 1
}

if ($Filenames -and $Unique) {
	Write-Host ""
	Write-Error "$ScriptName`: -Filenames is not supported with -Unique."
	exit 1
}

if ($Filenames -and $Description) {
	Write-Host ""
	Write-Warning "-Filenames suppresses flag details, so -Description has no effect."
}

if ($Align -and -not $Description) {
	Write-Host ""
	Write-Warning "-Align has no effect without -Description."
}

if ($Count -and -not $Unique -and -not $NoFlags) {
	Write-Host ""
	Write-Warning "-Count has no effect without -Unique."
}

if ($Missing -and -not $FlagFilter) {
	Write-Host ""
	Write-Warning "-Missing has no effect without -FlagFilter."
}

if ($NoFlags -and $Unique) {
	Write-Host ""
	Write-Error "$ScriptName`: -NoFlags is not supported with -Unique."
	exit 1
}

if ($NoFlags -and $FlagFilter) {
	Write-Host ""
	Write-Error "$ScriptName`: -NoFlags is not supported with -FlagFilter, since it lists scripts that have no flags to filter."
	exit 1
}

if ($NoFlags -and ($Align -or $Count -or $Description -or $Filenames -or $Missing)) {
	Write-Host ""
	Write-Warning "-Align, -Count, -Description, -Filenames, and -Missing have no effect with -NoFlags."
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

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "$ScriptName`: -NoConsoleOutput requires -SaveResults."
	exit 1
}

# Prompt for path if not specified
if (-not $Path) {
	if (-not $NoConsoleOutput) { Write-Host "" }
	$Path = Read-Host "Enter the full path to a .ps1 file or a folder containing scripts"
	if (-not $NoConsoleOutput) { Write-Host "" }
}

if (-not (Test-Path -LiteralPath $Path)) {
	$errorMessage = "$ScriptName`: The specified path does not exist."
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

# Collect scripts
if ((Get-Item -LiteralPath $Path).PSIsContainer) {
	$scripts = Get-ChildItem -LiteralPath $Path -Recurse:$Recurse -Filter *.ps1
}
else {
	if ($Path -like "*.ps1") {
		$scripts = @(Get-Item -LiteralPath $Path)
	}
	else {
		$errorMessage = "$ScriptName`: The specified file is not a PowerShell script (.ps1)."
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
}

# Skip scripts whose file names (or whose parent folders below the -Path folder) match any -Exclude wildcard pattern; the file name without .ps1 is checked too
if ($Exclude) {
	$pathItem = Get-Item -LiteralPath $Path
	$excludeRoot = if ($pathItem.PSIsContainer) { $pathItem.FullName.TrimEnd('\', '/') } else { $pathItem.DirectoryName }
	$scripts = @($scripts | Where-Object {
		$relativePath = $_.FullName.Substring($excludeRoot.Length).TrimStart('\', '/')
		$namesToCheck = @($relativePath -split '[\\/]') + $_.BaseName
		$excluded = $false
		foreach ($pattern in $Exclude) {
			foreach ($nameToCheck in $namesToCheck) {
				if ($nameToCheck -like $pattern) { $excluded = $true }
			}
		}
		-not $excluded
	})
}

# Keep only scripts whose file names (with or without .ps1) match at least one -Filter wildcard pattern
if ($Filter) {
	$scripts = @($scripts | Where-Object {
		$matched = $false
		foreach ($pattern in $Filter) {
			if ($_.Name -like $pattern -or $_.BaseName -like $pattern) { $matched = $true }
		}
		$matched
	})
}

if ($scripts.Count -eq 0) {
	$warningMessage = "$ScriptName`: No PowerShell scripts (.ps1) found."
	if ($Filter -or $Exclude) { $warningMessage = "$ScriptName`: No PowerShell scripts (.ps1) found after applying -Filter/-Exclude." }
	# -Filter patterns must match the whole file name, so a pattern without any wildcard character is a likely mistake
	if ($Filter -and -not ($Filter | Where-Object { $_ -match '[*?\[]' })) { $warningMessage += " -Filter patterns must match the whole file name, so add a wildcard (i.e. -Filter `"$($Filter[0])*`")." }
	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Warning $warningMessage
	}
	if ($SaveResults) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$warningMessage`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

$CsvOutputLines = @()
$allFlags = @{}
$flagCounts = @{}
$totalFlags = 0
$printedScripts = 0

# -NoFlags lists scripts that declare no flags instead of listing flags, using the same param block detection as the main loop below; the main loop is never reached in this mode
if ($NoFlags) {
	$isFolder = (Get-Item -LiteralPath $Path).PSIsContainer
	$rootPath = if ($isFolder) { (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\') } else { '' }
	$noFlagsScripts = @()
	$commentOnlyScripts = @()

	foreach ($script in $scripts) {
		$content = @(Get-Content -LiteralPath $script.FullName -ErrorAction SilentlyContinue)
		$relativePath = if ($isFolder) { $script.FullName.Substring($rootPath.Length + 1) } else { $script.Name }

		# Count the parameters with PowerShell's own parser, same as the main loop below
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$null)
		$parsedFlagCount = 0
		if ($ast.ParamBlock) { $parsedFlagCount = $ast.ParamBlock.Parameters.Count }

		if ($parsedFlagCount -gt 0) { continue }

		# A script with an # Optional flags comment block but no param block flags is inconsistent, so it's listed separately instead of as a plain script with no flags
		$hasCommentBlock = $false
		foreach ($line in $content) {
			if ($line -match '^\s*#\s*Optional flags\s*:?\s*$') {
				$hasCommentBlock = $true
				break
			}
		}

		if ($hasCommentBlock) { $commentOnlyScripts += $relativePath }
		else { $noFlagsScripts += $relativePath }
	}

	if (-not $NoConsoleOutput) {
		$noFlagsColor = if ($noFlagsScripts.Count -gt 0) { 'Yellow' } else { 'Green' }
		Write-Host "No flags: $($noFlagsScripts.Count)" -ForegroundColor $noFlagsColor
		foreach ($item in $noFlagsScripts) { Write-Host "  $item" }

		if ($commentOnlyScripts.Count -gt 0) {
			Write-Host "`nOptional flags comment block but no param block flags: $($commentOnlyScripts.Count)" -ForegroundColor Yellow
			foreach ($item in $commentOnlyScripts) { Write-Host "  $item" }
		}
	}

	if ($SaveResults) {
		foreach ($item in $noFlagsScripts) { $CsvOutputLines += "$item,No flags" }
		foreach ($item in $commentOnlyScripts) { $CsvOutputLines += "$item,Optional flags comment block but no param block flags" }
	}

	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Scanned $($scripts.Count) script(s): $($noFlagsScripts.Count) with no flags, $($commentOnlyScripts.Count) with an Optional flags comment block but no param block flags."
	if (-not $NoConsoleOutput) {
		$summaryColor = if ($noFlagsScripts.Count -gt 0 -or $commentOnlyScripts.Count -gt 0) { 'Yellow' } else { 'Green' }
		Write-Host "`n$summaryLine" -ForegroundColor $summaryColor
	}

	# Save results
	if ($SaveResults) {
		try {
			$outputString = ($CsvOutputLines -join "`n") + "`n"
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
}

foreach ($script in $scripts) {
	$content = Get-Content -LiteralPath $script.FullName -ErrorAction SilentlyContinue
	if (-not $content) { continue }

	# Read the param block with PowerShell's own parser so every parameter type is found (i.e. [string[]]) and comments or strings cannot end the block early
	$ast = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$null)
	if (-not $ast.ParamBlock -or $ast.ParamBlock.Parameters.Count -eq 0) { continue }

	$lines = $content

	# Build the hint lookup (and the description lookup if -Description is specified) from the # Optional flags comment block
	$hintMap = @{}
	$descriptionMap = @{}
	$inOptionalFlags = $false
	foreach ($line in $lines) {
		if ($line -match '#\s*Optional flags') {
			$inOptionalFlags = $true
			continue
		}
		if ($inOptionalFlags) {
			if ($line -match '^\s*#\s+(-\S+)') {
				$flagKey = $Matches[1] -replace '[^a-zA-Z0-9\-]', ''
				if ($line -match '^\s*#\s+-\w+\s+(<[^>]*>)') {
					$hintMap[$flagKey] = $Matches[1]
				}
				if ($Description -and $line -match ':\s+(.+)$') {
					$descriptionMap[$flagKey] = $Matches[1].Trim()
				}
			}
			elseif ($line -notmatch '^\s*#') {
				break
			}
		}
	}

	# Build each flag as it is written in the Optional flags comment block (i.e. -Path <PATH>); a flag with no hint there is listed without one
	$parsedFlags = @()
	foreach ($parameter in $ast.ParamBlock.Parameters) {
		$name = $parameter.Name.VariablePath.UserPath
		$hint = if ($hintMap.ContainsKey("-$name")) { " $($hintMap["-$name"])" } else { '' }
		$parsedFlags += "-$name$hint"
	}

	# If -FlagFilter is specified, skip scripts that don't match: normally scripts must contain ALL specified flags, but with -Missing scripts must be missing at least one of them instead
	if ($FlagFilter) {
		$allMatch = $true
		foreach ($filter in $FlagFilter) {
			$flagNormalized = $filter.TrimStart('-')
			if (-not ($parsedFlags | Where-Object { ($_ -split ' ')[0] -eq "-$flagNormalized" })) {
				$allMatch = $false
				break
			}
		}
		if ($Missing) {
			if ($allMatch) { continue }
		}
		else {
			if (-not $allMatch) { continue }
		}
	}

	# Accumulate flag counts, one per distinct form of a flag (i.e. -Backup and -Backup <PATH> are counted separately)
	foreach ($f in $parsedFlags) {
		if ($flagCounts.ContainsKey($f)) {
			$flagCounts[$f]++
		}
		else {
			$flagCounts[$f] = 1
		}
	}

	if (-not $Unique) {
		if ($Filenames) {
			if (-not $NoConsoleOutput) { Write-Host $script.Name -ForegroundColor Cyan }
			if ($SaveResults) { $CsvOutputLines += $script.Name }
			$totalFlags++
		}
		else {
			if ($scripts.Count -gt 1 -or $FlagFilter -or $Filter -or $Exclude) {
				# Separate scripts with a blank line before every script name except the first one printed
				if ($printedScripts -gt 0) {
					if (-not $NoConsoleOutput) { Write-Host "" }
					if ($SaveResults) { $CsvOutputLines += "" }
				}
				if (-not $NoConsoleOutput) { Write-Host $script.Name -ForegroundColor Cyan }
				if ($SaveResults) { $CsvOutputLines += $script.Name }
				$printedScripts++
			}

			$flagsToShow = if ($FlagFilter -and -not $Missing) {
				$parsedFlags | Where-Object {
					$baseName = ($_ -split ' ')[0]
					$FlagFilter | Where-Object { $baseName -eq "-$($_.TrimStart('-'))" }
				}
			}
			else {
				$parsedFlags
			}

			$padWidth = 0
			if ($Align -and $Description) {
				foreach ($f in $flagsToShow) {
					if ($f.Length -gt $padWidth) { $padWidth = $f.Length }
				}
			}

			foreach ($f in $flagsToShow) {
				$baseName = ($f -split ' ')[0]
				$fCsv = if ($f -match '[,"]') { '"' + ($f -replace '"', '""') + '"' } else { $f }
				$desc = if ($Description -and $descriptionMap.ContainsKey($baseName)) { $descriptionMap[$baseName] } else { "" }
				$descCsv = $desc -replace '"', '""'

				if ($Description -and $desc) {
					if (-not $NoConsoleOutput) {
						if ($Align) {
							$padded = $f.PadRight($padWidth)
							Write-Host "  $padded  $desc"
						}
						else {
							Write-Host "  $f`: $desc"
						}
					}
					if ($SaveResults) { $CsvOutputLines += "$fCsv,`"$descCsv`"" }
				}
				else {
					if (-not $NoConsoleOutput) { Write-Host "  $f" }
					if ($SaveResults) { $CsvOutputLines += $fCsv }
				}
				$totalFlags++
			}
		}
	}
	else {
		foreach ($f in $parsedFlags) {
			$allFlags[$f] = $true
		}
	}
}

# Output -Unique results
if ($Unique) {
	$sorted = $allFlags.Keys | Sort-Object @{ Expression = { ($_ -split ' ')[0] } }, @{ Expression = { $_ } }
	foreach ($key in $sorted) {
		$keyCsv = if ($key -match '[,"]') { '"' + ($key -replace '"', '""') + '"' } else { $key }
		$countSuffix = if ($Count) { " (Count: $($flagCounts[$key]))" } else { "" }
		if (-not $NoConsoleOutput) { Write-Host "  $key$countSuffix" }
		if ($SaveResults) {
			if ($Count) {
				$CsvOutputLines += "$keyCsv,$($flagCounts[$key])"
			}
			else {
				$CsvOutputLines += $keyCsv
			}
		}
		$totalFlags++
	}
}

$summaryLine = if ($Filenames) {
	"$ScriptName`: [$env:COMPUTERNAME] Scanned $($scripts.Count) script(s): $totalFlags script(s) matched."
}
elseif ($Unique) {
	"$ScriptName`: [$env:COMPUTERNAME] Scanned $($scripts.Count) script(s): $totalFlags unique flag(s) found."
}
else {
	"$ScriptName`: [$env:COMPUTERNAME] Scanned $($scripts.Count) script(s): $totalFlags flag(s) found."
}

if (-not $NoConsoleOutput) {
	Write-Host ""
	if ($totalFlags -eq 0) {
		Write-Warning $summaryLine
	}
	else {
		Write-Host $summaryLine -ForegroundColor Green
	}
}

# Save results
if ($SaveResults) {
	while ($CsvOutputLines.Count -gt 0 -and $CsvOutputLines[-1] -eq '') {
		$CsvOutputLines = @($CsvOutputLines | Select-Object -First ($CsvOutputLines.Count - 1))
	}
	try {
		$outputString = ($CsvOutputLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Results saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.