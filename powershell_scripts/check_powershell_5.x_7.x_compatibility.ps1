# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script uses PSScriptAnalyzer to check all PowerShell scripts in a user-specified directory for compatibility with PowerShell 5.x and 7.x

# Optional flags:
#     -CompactOutput:      Simplifies console output to match saved file style (removes separators and extra spacing)
#     -Failures:           Shows only scripts with issues in output
#     -Filenames:          Shows only script names with no per-version details (respects -Failures and -Successes)
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults)
#     -Path <PATH>:        Path to a .ps1 file or a folder (prompts if not specified)
#     -Recurse:            Include files in subdirectories
#     -SaveResults <PATH>: Save results to a text file (overwrites if file exists, with a hostname header identifying the machine the script was run from)
#     -Successes:          Shows only scripts with no issues in output
#     -Summary:            Shows a summary of analyzed scripts at the end
#     -Help / -?:          Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$CompactOutput,
	[switch]$Failures,
	[switch]$Filenames,
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
	Write-Host "`nUsage:`n    .\$ScriptName [-CompactOutput] [-Failures] [-Filenames] [-NoConsoleOutput] [-Path <PATH>] [-Recurse] [-SaveResults <PATH>] [-Successes] [-Summary] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CompactOutput       Simplifies console output to match saved file style (removes separators and extra spacing)" -ForegroundColor Cyan
	Write-Host "  -Failures            Show only scripts with compatibility issues" -ForegroundColor Cyan
	Write-Host "  -Filenames           Show only script names with no per-version details (respects -Failures and -Successes)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Path <PATH>         Path to a .ps1 file or a folder (prompts if not specified)" -ForegroundColor Cyan
	Write-Host "  -Recurse             Include files in subdirectories" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (overwrites if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Successes           Show only scripts with no compatibility issues" -ForegroundColor Cyan
	Write-Host "  -Summary             Show a summary of total scripts analyzed, passed, and failed" -ForegroundColor Cyan
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

# Warn if -Successes and -Failures are both specified (mutually exclusive)
if ($Successes -and $Failures) {
	Write-Host ""
	Write-Warning "-Successes and -Failures are mutually exclusive. Please use only one at a time."
	exit 1
}

# -Filenames already prints only script names, so -CompactOutput has nothing to simplify
if ($Filenames -and $CompactOutput) {
	Write-Host ""
	Write-Error "-Filenames and -CompactOutput cannot be used together."
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
	Write-Host ""
	$Path = Read-Host "Enter the full path to a .ps1 file or a folder containing scripts"
	Write-Host ""
	$promptedForPath = $true
}

if (-not (Test-Path -LiteralPath $Path)) {
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
if ((Get-Item -LiteralPath $Path).PSIsContainer) {
	$scripts = Get-ChildItem -LiteralPath $Path -Recurse:$Recurse -Filter *.ps1
}
else {
	if ($Path -like "*.ps1") {
		$scripts = @(Get-Item -LiteralPath $Path)
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
			[System.IO.File]::WriteAllText($SaveResults, "$env:COMPUTERNAME`:`nNo PowerShell scripts (.ps1) found.")
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
$pwshPaths = Get-ChildItem (Join-Path $env:ProgramFiles 'PowerShell') -Directory -ErrorAction SilentlyContinue
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
$FileOutputLines = @("$env:COMPUTERNAME`:")
$summaryLine = ""

# Analyze each script
# Find the PSScriptAnalyzer compatibility profile that best matches each PowerShell version, so no profile names are hardcoded
$analyzerModule = Get-Module PSScriptAnalyzer -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
$profileNames = @()
if ($analyzerModule) {
	$profileNames = @(Get-ChildItem -LiteralPath (Join-Path $analyzerModule.ModuleBase 'compatibility_profiles') -Filter *.json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName)
}

$profileCandidates = foreach ($profileName in $profileNames) {
	if ($profileName -match '^win-\d+_x64_10\.0\.(?<build>\d+)\.\d+_(?<ps>\d+\.\d+)\.[\d.]+_x64_') {
		[pscustomobject]@{ Name = $profileName; PS = [version]$Matches['ps']; Build = [int]$Matches['build'] }
	}
}

# For each installed version, use the newest profile for the same major version that is not newer than the installed version (then the newest Windows build)
$versionProfiles = @{}
foreach ($version in $VersionsToCheck) {
	$installedVersion = [version](($version -split '\.')[0..1] -join '.')
	$bestProfile = $profileCandidates | Where-Object { $_.PS.Major -eq $installedVersion.Major -and $_.PS -le $installedVersion } | Sort-Object PS, Build -Descending | Select-Object -First 1
	$versionProfiles[$version] = $bestProfile.Name

	if (-not $bestProfile) {
		$warningLine = "No PSScriptAnalyzer compatibility profile found for PowerShell $version, so command compatibility will not be checked for it."
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $warningLine
		}
		if ($SaveResults) {
			$FileOutputLines += $warningLine
		}
	}
}

$printedAny = $false
$seenIssues = @{}

for ($i = 0; $i -lt $scripts.Count; $i++) {
	$script = $scripts[$i]
	$hasIssues = $false
	$scriptOutput = @()  # store console output temporarily

	foreach ($version in $VersionsToCheck) {
		try {
			# Compare against the compatibility profile found for this version (the newest bundled profile may be older than the installed version, so features added since may be reported as unavailable)
			$syntaxVersion = '7.0'
			if ($version -like '5.*') {
				$syntaxVersion = '5.1'
			}
			$analyzerSettings = @{
				Severity = @('Warning')
				ExcludeRules = @('PSAvoidUsingWriteHost')
				Rules = @{
					PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @($syntaxVersion) }
				}
			}
			if ($versionProfiles[$version]) {
				$analyzerSettings.Rules['PSUseCompatibleCommands'] = @{ Enable = $true; TargetProfiles = @($versionProfiles[$version]) }
			}
			$results = Invoke-ScriptAnalyzer -Path $script.FullName -Recurse -Settings $analyzerSettings

			# Filter a known false positive: -Type on Set-ItemProperty is a dynamic parameter added by the Registry provider, which the compatibility profiles do not include
			$results = @($results | Where-Object { $_.Message -notmatch "parameter 'Type' is not available for command 'Set-ItemProperty'" })
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

		# Rules that do not depend on the version return identical results on every pass, so keep each distinct issue only once
		foreach ($result in $results) {
			$issueKey = "$($result.ScriptName)|$($result.RuleName)|$($result.Line)|$($result.Message)"
			if (-not $seenIssues.ContainsKey($issueKey)) {
				$seenIssues[$issueKey] = $true
				$AllResults += $result
			}
		}
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
		if ($Filenames) {
			$FileOutputLines += $script.Name
		}
		else {
			$FileOutputLines += "Script: $($script.FullName)"
			$FileOutputLines += $scriptOutput
			if (-not $CompactOutput) {
				$FileOutputLines += ""  # blank line between scripts
			}
		}
	}

	# -Filenames prints only the script name
	if ($Filenames -and $scriptOutput.Count -gt 0 -and -not $NoConsoleOutput) {
		$color = if ($hasIssues) { 'Yellow' } else { 'Green' }
		Write-Host $script.Name -ForegroundColor $color
		$printedAny = $true
	}
	# Only print to console if output exists
	elseif ($scriptOutput.Count -gt 0 -and -not $NoConsoleOutput) {
		# For -Failures (non-compact mode), separate printed scripts with a blank line
		if ($Failures -and -not $CompactOutput -and $printedAny) {
			Write-Host ""
		}

		if (-not $CompactOutput) {
			Write-Host "=========================================" -ForegroundColor DarkCyan
		}
		Write-Host "Analyzing script: $($script.FullName)" -ForegroundColor Cyan
		$printedAny = $true

		foreach ($line in $scriptOutput) {
			$color = if ($hasIssues) { 'Yellow' } else { 'Green' }
			Write-Host $line -ForegroundColor $color
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
		if ($printedAny -or -not $promptedForPath) {
			Write-Host ""
		}
		Write-Host $summaryLine -ForegroundColor Cyan
	}
}

# Save results to text file if requested
if ($SaveResults) {
	# Remove trailing blank lines
	while ($FileOutputLines[-1] -eq '') {
		$FileOutputLines = @($FileOutputLines | Select-Object -First ($FileOutputLines.Count - 1))
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
			Write-Host "`n$ScriptName`: Results saved to text file: $SaveResults" -ForegroundColor Green
		}
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

if ($Failures -and $AllResults.Count -eq 0 -and -not $NoConsoleOutput) {
	if (-not $Summary -and -not $promptedForPath) {
		Write-Host ""
	}
	Write-Host "Scripts scanned: $($scripts.Count) - No failures found." -ForegroundColor Green
}

# Unconditional completion line
$completionLine = "$ScriptName`: [$env:COMPUTERNAME] Completed successfully."
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
	Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.