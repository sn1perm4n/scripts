# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans PowerShell scripts and lists all flags defined in their param blocks

# Optional flags:
#     -Align:                 Align flag descriptions into two columns when used with -Description (console output only)
#     -Count:                 Show the number of scripts each flag appears in (only meaningful with -Unique)
#     -Description:           Include flag descriptions from the # Optional flags comment block
#     -Exclude:               Show scripts missing at least one flag specified via -FlagFilter, instead of scripts containing all of them (requires -FlagFilter)
#     -Filenames:             Print only script names with no flag details or blank lines between entries
#     -FlagFilter <NAME,...>: Filter output to only scripts containing all specified flags (comma-separated, i.e. -FlagFilter "-SaveResults,-NoConsoleOutput")
#     -NoConsoleOutput:       Suppress console output (requires -SaveResults)
#     -Path <PATH>:           Path to a PowerShell script (.ps1) or folder (prompts if not specified)
#     -Recurse:               Search subdirectories recursively
#     -SaveResults <PATH>:    Save results to a .csv file (appends if file exists)
#     -Unique:                Show only unique deduplicated flag names in an alphabetized list
#     -Help / -?:             Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Align,
	[switch]$Count,
	[switch]$Description,
	[switch]$Exclude,
	[switch]$Filenames,
	[string[]]$FlagFilter,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Unique,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Align] [-Count] [-Description] [-Exclude] [-Filenames] [-FlagFilter <NAME,...>] [-NoConsoleOutput] [-Path <PATH>] [-Recurse] [-SaveResults <PATH>] [-Unique] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Align                  Align flag descriptions into two columns when used with -Description (console output only)" -ForegroundColor Cyan
	Write-Host "  -Count                  Show the number of scripts each flag appears in (only meaningful with -Unique)" -ForegroundColor Cyan
	Write-Host "  -Description            Include flag descriptions from the # Optional flags comment block" -ForegroundColor Cyan
	Write-Host "  -Exclude                Show scripts missing at least one flag specified via -FlagFilter, instead of scripts containing all of them (requires -FlagFilter)" -ForegroundColor Cyan
	Write-Host "  -Filenames              Print only script names with no flag details or blank lines between entries" -ForegroundColor Cyan
	Write-Host "  -FlagFilter <NAME,...>  Filter output to only scripts containing all specified flags (comma-separated, i.e. -FlagFilter `"-SaveResults,-NoConsoleOutput`")" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput        Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>            Path to a PowerShell script (.ps1) or folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse                Search subdirectories recursively" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>     Save results to a .csv file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Unique                 Show only unique deduplicated flag names in an alphabetized list" -ForegroundColor Cyan
	Write-Host "  -Help                   Display this help message" -ForegroundColor Cyan
	Write-Host ""
	exit 0
}

# Normalize -FlagFilter so a single comma-separated string works the same as multiple values
if ($FlagFilter) {
	$FlagFilter = $FlagFilter | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Warn on unsupported flag combinations
if ($Description -and $Unique) {
	Write-Host ""
	Write-Warning "-Description is not supported with -Unique. Descriptions may vary per script and would be misleading in deduplicated output. Run without -Unique to see descriptions per script."
	exit 1
}

if ($Filenames -and $Unique) {
	Write-Host ""
	Write-Warning "-Filenames is not supported with -Unique."
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

if ($Exclude -and -not $FlagFilter) {
	Write-Host ""
	Write-Warning "-Exclude has no effect without -FlagFilter."
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

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Prompt for path if not specified
if (-not $Path) {
	if (-not $NoConsoleOutput) { Write-Host "" }
	$Path = Read-Host "Enter the full path to a .ps1 file or a folder containing scripts"
	if (-not $NoConsoleOutput) { Write-Host "" }
}

if (-not (Test-Path $Path)) {
	$errorMessage = "The specified path does not exist."
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
if ((Get-Item $Path).PSIsContainer) {
	$scripts = Get-ChildItem -Path $Path -Recurse:$Recurse -Filter *.ps1
}
else {
	if ($Path -like "*.ps1") {
		$scripts = @(Get-Item $Path)
	}
	else {
		$errorMessage = "The specified file is not a PowerShell script (.ps1)."
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

if ($scripts.Count -eq 0) {
	$warningMessage = "$ScriptName`: No PowerShell scripts (.ps1) found."
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

foreach ($script in $scripts) {
	$content = Get-Content -Path $script.FullName -ErrorAction SilentlyContinue
	if (-not $content) { continue }

	# Find param block
	$paramStart = -1
	for ($i = 0; $i -lt $content.Count; $i++) {
		if ($content[$i] -match '^\s*param\s*\(') {
			$paramStart = $i
			break
		}
	}

	if ($paramStart -eq -1) { continue }

	$paramLines = @()
	$depth = 1
	for ($i = $paramStart + 1; $i -lt $content.Count; $i++) {
		$line = $content[$i]
		foreach ($char in $line.ToCharArray()) {
			if ($char -eq '(') { $depth++ }
			elseif ($char -eq ')') { $depth-- }
		}
		if ($depth -le 0) { break }
		$paramLines += $line
	}

	if ($paramLines.Count -eq 0) { continue }

	$lines = $content

	# Parse flags from param lines
	$parsedFlags = @()
	foreach ($line in $paramLines) {
		if ($line -match '^\s*\[(switch|string|int|bool|double)\]\$(\w+)') {
			$type = $Matches[1]
			$name = $Matches[2]

			$hint = switch ($type) {
				'string' { ' <PATH>' }
				'int'    { ' <N>' }
				'double' { ' <N>' }
				default  { '' }
			}

			$parsedFlags += "-$name$hint"
		}
	}

	if ($parsedFlags.Count -eq 0) { continue }

	# If -FlagFilter is specified, skip scripts that don't match: normally scripts must contain ALL specified flags, but with -Exclude scripts must be missing at least one of them instead
	if ($FlagFilter) {
		$allMatch = $true
		foreach ($filter in $FlagFilter) {
			$flagNormalized = $filter.TrimStart('-')
			if (-not ($parsedFlags | Where-Object { ($_ -split ' ')[0] -eq "-$flagNormalized" })) {
				$allMatch = $false
				break
			}
		}
		if ($Exclude) {
			if ($allMatch) { continue }
		}
		else {
			if (-not $allMatch) { continue }
		}
	}

	# Build description lookup from # Optional flags comment block if -Description specified
	$descriptionMap = @{}
	if ($Description) {
		$inOptionalFlags = $false
		foreach ($line in $lines) {
			if ($line -match '#\s*Optional flags') {
				$inOptionalFlags = $true
				continue
			}
			if ($inOptionalFlags) {
				if ($line -match '^\s*#\s+(-\S+)') {
					$flagKey = $Matches[1] -replace '[^a-zA-Z0-9\-]', ''
					if ($line -match ':\s+(.+)$') {
						$descriptionMap[$flagKey] = $Matches[1].Trim()
					}
				}
				elseif ($line -notmatch '^\s*#') {
					break
				}
			}
		}
	}

	# Accumulate flag counts
	foreach ($f in $parsedFlags) {
		$baseName = ($f -split ' ')[0]
		if ($flagCounts.ContainsKey($baseName)) {
			$flagCounts[$baseName]++
		}
		else {
			$flagCounts[$baseName] = 1
		}
	}

	if (-not $Unique) {
		if ($Filenames) {
			if (-not $NoConsoleOutput) { Write-Host $script.Name -ForegroundColor Cyan }
			if ($SaveResults) { $CsvOutputLines += $script.Name }
			$totalFlags++
		}
		else {
			if ($scripts.Count -gt 1 -or $FlagFilter) {
				if (-not $NoConsoleOutput) { Write-Host $script.Name -ForegroundColor Cyan }
				if ($SaveResults) { $CsvOutputLines += $script.Name }
			}

			$flagsToShow = if ($FlagFilter -and -not $Exclude) {
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
				$desc = if ($Description -and $descriptionMap.ContainsKey($baseName)) { $descriptionMap[$baseName] } else { "" }

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
					if ($SaveResults) { $CsvOutputLines += "$f,`"$desc`"" }
				}
				else {
					if (-not $NoConsoleOutput) { Write-Host "  $f" }
					if ($SaveResults) { $CsvOutputLines += $f }
				}
				$totalFlags++
			}

			if (($scripts.Count -gt 1 -or $FlagFilter) -and $script -ne $scripts[-1]) {
				if (-not $NoConsoleOutput) { Write-Host "" }
				if ($SaveResults) { $CsvOutputLines += "" }
			}
		}
	}
	else {
		foreach ($f in $parsedFlags) {
			$baseName = ($f -split ' ')[0]
			if (-not $allFlags.ContainsKey($baseName)) {
				$allFlags[$baseName] = $f
			}
		}
	}
}

# Output -Unique results
if ($Unique) {
	$sorted = $allFlags.Keys | Sort-Object
	foreach ($key in $sorted) {
		$countSuffix = if ($Count) { " (Count: $($flagCounts[$key]))" } else { "" }
		if (-not $NoConsoleOutput) { Write-Host "  $($allFlags[$key])$countSuffix" }
		if ($SaveResults) {
			if ($Count) {
				$CsvOutputLines += "$($allFlags[$key]),$($flagCounts[$key])"
			}
			else {
				$CsvOutputLines += $allFlags[$key]
			}
		}
		$totalFlags++
	}
}

$summaryLine = if ($Filenames) {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags script(s) matched."
}
elseif ($Unique) {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags unique flag(s) found."
}
else {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags flag(s) found."
}

if (-not $NoConsoleOutput) {
	if ($Filenames) { Write-Host "" }
	if ($Unique) { Write-Host "" }
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
		$CsvOutputLines = $CsvOutputLines[0..($CsvOutputLines.Count - 2)]
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