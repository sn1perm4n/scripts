# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses PSScriptAnalyzer to check all PowerShell scripts in a user-specified directory for compatibility with PowerShell 5.x and 7.x

# Optional flags:
#     -CompactOutput: Simplifies console output to match saved file style (removes separators and extra spacing)
#     -Failures: Shows only scripts with issues in output
#     -NoConsoleOutput: Suppress console output (requires -SaveResults)
#     -Path <PATH>: Path to a .ps1 file or a folder (prompts if not specified)
#     -Recurse: Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (i.e. -SaveResults "C:\output.txt")
#     -Successes: Shows only scripts with no issues in output
#     -Summary: Shows a summary of analyzed scripts at the end
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$CompactOutput,
	[switch]$Failures,
	[switch]$NoConsoleOutput,
	[string]$Path,
	[switch]$Recurse,
	[string]$SaveResults,
	[switch]$Successes,
	[switch]$Summary,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-CompactOutput] [-Failures] [-NoConsoleOutput] [-Path <PATH>] [-Recurse] [-Successes] [-Summary] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CompactOutput       Simplifies console output to match saved file style (removes separators and extra spacing)" -ForegroundColor Cyan
	Write-Host "  -Failures            Show only scripts with compatibility issues" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a .ps1 file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -Successes           Show only scripts with no compatibility issues" -ForegroundColor Cyan
	Write-Host "  -Summary             Show a summary of total scripts analyzed, passed, and failed" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (i.e. -SaveResults ""C:\output.txt"")" -ForegroundColor Cyan
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

# Warn if -Successes and -Failures are both specified (mutually exclusive)
if ($Successes -and $Failures) {
	Write-Host ""
	Write-Warning "-Successes and -Failures are mutually exclusive. Please use only one at a time."
	exit 1
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Ensure PSScriptAnalyzer module is installed
try {
	if (-not $NoConsoleOutput) { Write-Host "`nChecking for PSScriptAnalyzer module..." -ForegroundColor Cyan }
	if (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer')) {
		if (-not $NoConsoleOutput) { Write-Host "PSScriptAnalyzer module not found. Installing..." -ForegroundColor Yellow }
		Install-Module -Name PSScriptAnalyzer -Repository PSGallery -Force -Scope CurrentUser -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "PSScriptAnalyzer module installed successfully." -ForegroundColor Green }
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "PSScriptAnalyzer module already installed." -ForegroundColor Green }
	}
	Import-Module PSScriptAnalyzer -ErrorAction Stop
}
catch {
	$errorMessage = "Failed to install or import PSScriptAnalyzer: $($_.Exception.Message)"
	if ($NoConsoleOutput) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$errorMessage`n")
		}
		catch {
			Write-Host ""
			Write-Warning $errorMessage
		}
	}
	else {
		Write-Host ""
		Write-Warning $errorMessage
	}
	exit 1
}

# Prompt user for file or folder path if not specified
if (-not $Path) {
	Write-Host ""  # blank line before prompt
	$Path = Read-Host "Enter the full path to a .ps1 file or a folder containing scripts"
	Write-Host ""  # blank line after prompt
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
	if (-not $NoConsoleOutput) { Write-Host "No PowerShell scripts (.ps1) found." -ForegroundColor Cyan }
	if ($SaveResults) {
		try {
			[System.IO.File]::WriteAllText($SaveResults, "No PowerShell scripts (.ps1) found.")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
		}
	}
	exit 0
}

# Detect installed PowerShell versions
$PS5Version = if ($PSVersionTable.PSVersion.Major -eq 5) {
	"$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
}
else {
	& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
}

$Detected7Versions = @()
$pwshPaths = Get-ChildItem 'C:\Program Files\PowerShell' -Directory -ErrorAction SilentlyContinue
foreach ($dir in $pwshPaths) {
	$pwshExe = Join-Path $dir.FullName 'pwsh.exe'
	if (Test-Path $pwshExe) {
		$ver = & $pwshExe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
		$Detected7Versions += $ver
	}
}
$Detected7Versions = $Detected7Versions | Sort-Object -Unique

$VersionsToCheck = @($PS5Version) + $Detected7Versions

# Initialize collections
$AllResults = @()
$FileOutputLines = @()
$summaryLine = ""

# Analyze each script
for ($i = 0; $i -lt $scripts.Count; $i++) {
	$script = $scripts[$i]
	$hasIssues = $false
	$scriptOutput = @()  # store console output temporarily

	foreach ($version in $VersionsToCheck) {
		try {
			$results = Invoke-ScriptAnalyzer -Path $script.FullName -Recurse -Severity Warning -ExcludeRule PSAvoidUsingWriteHost
		}
		catch {
			$warningLine = "Error analyzing $($script.FullName) for PowerShell $version compatibility: $($_.Exception.Message)"
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning $warningLine
			}
			if ($SaveResults) {
				$FileOutputLines += $warningLine
			}
			continue
		}

		if (-not $CompactOutput) {
			$scriptOutput += "--- PowerShell $version Compatibility ---"
		}
		else {
			$scriptOutput += "PowerShell $version Compatibility:"
		}

		if ($results.Count -gt 0) {
			$hasIssues = $true
			foreach ($issue in $results) {
				$line = "[{0}] {1} (Line {2})" -f $issue.RuleName, $issue.Message, $issue.Line
				$scriptOutput += $line
			}
		}
		elseif ($Successes -or (-not $Failures -and -not $Successes)) {
			# Add "No compatibility issues detected." for -Successes or default behavior
			$scriptOutput += "No compatibility issues detected."
		}

		$AllResults += $results
	}

	# Successes prints only scripts with no issues
	if ($Successes -and $hasIssues) {
		$scriptOutput = @()
	}

	# Failures prints only scripts with issues
	if ($Failures -and -not $hasIssues) {
		$scriptOutput = @()
	}

	# Save file output if requested, respecting -Failures and -Successes filters
	if ($SaveResults -and $scriptOutput.Count -gt 0) {
		$FileOutputLines += "Script: $($script.FullName)"
		$FileOutputLines += $scriptOutput
		if (-not $CompactOutput) {
			$FileOutputLines += ""  # blank line between scripts
		}
	}

	# Only print to console if output exists
	if ($scriptOutput.Count -gt 0 -and -not $NoConsoleOutput) {
		if (-not $CompactOutput) {
			Write-Host "=========================================" -ForegroundColor DarkCyan
		}
		Write-Host "Analyzing script: $($script.FullName)" -ForegroundColor Cyan

		foreach ($line in $scriptOutput) {
			$color = if ($hasIssues) { 'Yellow' } else { 'Green' }
			Write-Host $line -ForegroundColor $color
		}

		# Add a blank line between scripts only for -Failures (non-compact mode)
		if ($Failures -and -not $CompactOutput -and $i -lt ($scripts.Count - 1)) {
			Write-Host ""
		}

		if (-not $CompactOutput -and $i -lt ($scripts.Count - 1) -and -not $Failures) {
			Write-Host ""
		}
	}
}

# Display summary if requested
if ($Summary) {
	$TotalScripts = $scripts.Count
	$TotalIssues = $AllResults.Count
	$FailedScripts = ($AllResults | Select-Object -ExpandProperty ScriptName | Sort-Object -Unique).Count
	$PassedScripts = $TotalScripts - $FailedScripts

	$summaryLine = "Analysis complete! Analyzed $TotalScripts scripts: $PassedScripts passed, $FailedScripts failed, $TotalIssues issues detected."

	if (-not $NoConsoleOutput) {
		# Handle newlines before summary
		if ($Failures -and $CompactOutput) {
			Write-Host ""
		}
		elseif (-not $Failures) {
			Write-Host ""  # normal spacing for other flags
		}
		Write-Host $summaryLine -ForegroundColor Cyan
	}
}

# Save results to text file if requested
if ($SaveResults) {
	# Remove trailing blank lines
	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = $FileOutputLines[0..($FileOutputLines.Count - 2)]
	}

	# Append summary line if requested
	if ($Summary -and $summaryLine -ne '') {
		$FileOutputLines += ""
		$FileOutputLines += $summaryLine
	}

	try {
		$outputString = ($FileOutputLines -join "`n")
		[System.IO.File]::WriteAllText($SaveResults, $outputString)
		if (-not $NoConsoleOutput) {
			if ($Failures -and -not $CompactOutput -and -not $Summary) {
				Write-Host "$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green
			}
			else {
				Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green
			}
		}
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

if ($Failures -and $AllResults.Count -eq 0 -and -not $NoConsoleOutput) {
	Write-Host "Scripts scanned: $($scripts.Count) - No failures found." -ForegroundColor Green
}

# Unconditional completion line
$completionLine = "$ScriptName`: Completed successfully."
if (-not $NoConsoleOutput) { Write-Host "`n$completionLine" -ForegroundColor Green }
if ($SaveResults) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "`n$completionLine")
	}
	catch {
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Keep window open
if (-not $NoConsoleOutput) {
	if ($Failures -and $AllResults.Count -gt 0 -and -not $Summary -and -not $SaveResults) {
		Write-Host "Press any key to exit..." -ForegroundColor Cyan
	}
	else {
		Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
	}
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.