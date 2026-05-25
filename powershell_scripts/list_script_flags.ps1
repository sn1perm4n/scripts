# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script scans PowerShell scripts and lists all flags defined in their param blocks

# Optional flags:
#     -Description: Include flag descriptions from the # Optional flags comment block
#     -Path <PATH>: Path to a PowerShell script (.ps1) or folder (prompts if not specified)
#     -Recurse: Search subdirectories recursively
#     -SaveResults <PATH>: Save results to a .csv file (appends if file exists)
#     -Unique: Show only unique deduplicated flag names in an alphabetized list
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Description,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Unique,
	[switch]$Help
)

$ScriptName = Split-Path $PSCommandPath -Leaf

if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Description] [-Path <PATH>] [-Recurse] [-SaveResults <PATH>] [-Unique] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Description         Include flag descriptions from the # Optional flags comment block" -ForegroundColor Cyan
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
$allFlags = @{}  # used for -Unique: key = normalized flag name, value = flag display string
$totalFlags = 0

foreach ($script in $scripts) {
	$content = Get-Content -Path $script.FullName -ErrorAction SilentlyContinue
	if (-not $content) { continue }

	# Find param block
	$inParam = $false
	$paramLines = @()
	$braceDepth = 0

	foreach ($line in $content) {
		if (-not $inParam -and $line -match '^\s*param\s*\(') {
			$inParam = $true
		}
		if ($inParam) {
			$paramLines += $line
			$braceDepth += ($line.ToCharArray() | Where-Object { $_ -eq '(' } | Measure-Object).Count
			$braceDepth -= ($line.ToCharArray() | Where-Object { $_ -eq ')' } | Measure-Object).Count
			if ($braceDepth -le 0) { break }
		}
	}

	if ($paramLines.Count -eq 0) { continue }

	# Parse flags from param block
	$flags = @()
	foreach ($line in $paramLines) {
		if ($line -match '^\s*\[(switch|string|int|bool|double)\]\$(\w+)') {
			$type = $Matches[1]
			$name = $Matches[2]

			# Convert type to display hint
			$hint = switch ($type) {
				'string' { ' <PATH>' }
				'int'    { ' <N>' }
				'double' { ' <N>' }
				default  { '' }
			}

			$flagDisplay = "-$name$hint"
			$flags += $flagDisplay
		}
	}

	if ($flags.Count -eq 0) { continue }

	# Build description lookup from # Optional flags comment block if -Description specified
	$descriptionMap = @{}
	if ($Description) {
		$inOptionalFlags = $false
		foreach ($line in $content) {
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

	if (-not $Unique) {
		# Print script name header (skip for single file)
		if ($scripts.Count -gt 1) {
			Write-Host $script.Name -ForegroundColor Cyan
			if ($SaveResults) { $CsvOutputLines += $script.Name }
		}

		foreach ($flag in $flags) {
			$baseName = ($flag -split ' ')[0]
			$desc = if ($Description -and $descriptionMap.ContainsKey($baseName)) { $descriptionMap[$baseName] } else { "" }

			if ($Description -and $desc) {
				Write-Host "  $flag`: $desc"
				if ($SaveResults) { $CsvOutputLines += "$flag,`"$desc`"" }
			} else {
				Write-Host "  $flag"
				if ($SaveResults) { $CsvOutputLines += $flag }
			}
			$totalFlags++
		}

		if ($scripts.Count -gt 1 -and $script -ne $scripts[-1]) {
			Write-Host ""
			if ($SaveResults) { $CsvOutputLines += "" }
		}
	} else {
		# Accumulate for -Unique
		foreach ($flag in $flags) {
			$baseName = ($flag -split ' ')[0]
			if (-not $allFlags.ContainsKey($baseName)) {
				$allFlags[$baseName] = $flag
			}
		}
	}
}

# Output -Unique results
if ($Unique) {
	$sorted = $allFlags.Keys | Sort-Object
	foreach ($key in $sorted) {
		Write-Host "  $($allFlags[$key])"
		if ($SaveResults) { $CsvOutputLines += $allFlags[$key] }
		$totalFlags++
	}
}

$summaryLine = if ($Unique) {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags unique flag(s) found."
} else {
	"$ScriptName`: Scanned $($scripts.Count) script(s): $totalFlags flag(s) found."
}
if ($Unique) { Write-Host "" }
Write-Host "$summaryLine" -ForegroundColor Green

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