# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans PowerShell scripts and lists all flags defined in their param blocks

# Optional flags:
#     -Count: Show the number of scripts each flag appears in (only meaningful with -Unique)
#     -Description: Include flag descriptions from the # Optional flags comment block
#     -Flag <NAME>: Filter output to only scripts containing the specified flag
#     -Path <PATH>: Path to a PowerShell script (.ps1) or folder (prompts if not specified)
#     -Recurse: Search subdirectories recursively
#     -SaveResults <PATH>: Save results to a .csv file (appends if file exists)
#     -Unique: Show only unique deduplicated flag names in an alphabetized list
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Count,
	[switch]$Description,
	[string]$FlagFilter,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Unique,
	[switch]$Help
)

$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Count] [-Description] [-Flag <NAME>] [-Path <PATH>] [-Recurse] [-SaveResults <PATH>] [-Unique] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Count               Show the number of scripts each flag appears in (only meaningful with -Unique)" -ForegroundColor Cyan
	Write-Host "  -Description         Include flag descriptions from the # Optional flags comment block" -ForegroundColor Cyan
	Write-Host "  -Flag <NAME>         Filter output to only scripts containing the specified flag" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a PowerShell script (.ps1) or folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Search subdirectories recursively" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a .csv file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Unique              Show only unique deduplicated flag names in an alphabetized list" -ForegroundColor Cyan
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

# Prompt for path if not specified
if (-not $Path) {
	Write-Host ""
	$Path = Read-Host "Enter the full path to a PowerShell script (.ps1) or folder"
	Write-Host ""
}

if (-not (Test-Path $Path)) {
	Write-Host ""
	Write-Error "The specified path does not exist."
	exit 1
}

# Collect scripts
if ((Get-Item $Path).PSIsContainer) {
	$scripts = Get-ChildItem -Path $Path -Recurse:$Recurse -Filter *.ps1
} else {
	if ($Path -like "*.ps1") {
		$scripts = @(Get-Item $Path)
	} else {
		Write-Host ""
		Write-Error "The specified file is not a PowerShell script (.ps1)."
		exit 1
	}
}

if ($scripts.Count -eq 0) {
	Write-Host "No PowerShell scripts (.ps1) found." -ForegroundColor Yellow
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

	# If -Flag is specified, skip scripts that don't contain the flag
	if ($FlagFilter) {
		$flagNormalized = $FlagFilter.TrimStart('-')
		$hasFlag = $parsedFlags | Where-Object { ($_ -split ' ')[0] -eq "-$flagNormalized" }
		if (-not $hasFlag) { continue }
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
				} elseif ($line -notmatch '^\s*#') {
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
		} else {
			$flagCounts[$baseName] = 1
		}
	}

	if (-not $Unique) {
		if ($scripts.Count -gt 1 -or $FlagFilter) {
			Write-Host $script.Name -ForegroundColor Cyan
			if ($SaveResults) { $CsvOutputLines += $script.Name }
		}

		$flagsToShow = if ($FlagFilter) {
			$flagNormalized = $FlagFilter.TrimStart('-')
			$parsedFlags | Where-Object { ($_ -split ' ')[0] -eq "-$flagNormalized" }
		} else {
			$parsedFlags
		}

		foreach ($f in $flagsToShow) {
			$baseName = ($f -split ' ')[0]
			$desc = if ($Description -and $descriptionMap.ContainsKey($baseName)) { $descriptionMap[$baseName] } else { "" }

			if ($Description -and $desc) {
				Write-Host "  $f`: $desc"
				if ($SaveResults) { $CsvOutputLines += "$f,`"$desc`"" }
			} else {
				Write-Host "  $f"
				if ($SaveResults) { $CsvOutputLines += $f }
			}
			$totalFlags++
		}

		if (($scripts.Count -gt 1 -or $FlagFilter) -and $script -ne $scripts[-1]) {
			Write-Host ""
			if ($SaveResults) { $CsvOutputLines += "" }
		}
	} else {
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
		Write-Host "  $($allFlags[$key])$countSuffix"
		if ($SaveResults) {
			if ($Count) {
				$CsvOutputLines += "$($allFlags[$key]),$($flagCounts[$key])"
			} else {
				$CsvOutputLines += $allFlags[$key]
			}
		}
		$totalFlags++
	}
}

$summaryLine = if ($Unique) {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags unique flag(s) found."
} else {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags flag(s) found."
}

if ($Unique) { Write-Host "" }
Write-Host $summaryLine -ForegroundColor Green

# Save results
if ($SaveResults) {
	while ($CsvOutputLines.Count -gt 0 -and $CsvOutputLines[-1] -eq '') {
		$CsvOutputLines = $CsvOutputLines[0..($CsvOutputLines.Count - 2)]
	}
	try {
		$outputString = ($CsvOutputLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $outputString)
		Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green
	} catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.