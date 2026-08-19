# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script hides or shows KB5007651 in Windows Update, useful now that Microsoft is deprecating the wushowhide.diagcab tool

# NOTE: This script targets only KB5007651; the KB number is hardcoded as $TargetKB below rather than exposed as a parameter

# Optional flags:
#     -Hide:               Hide KB5007651 from Windows Update (mutually exclusive with -Preview and -Show)
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults)
#     -Preview:            Report whether KB5007651 is currently hidden, visible, or not applicable, without changing anything
#     -SaveResults <PATH>: Save results to a text file (appends if file exists)
#     -Show:               Show/unhide KB5007651 in Windows Update (mutually exclusive with -Hide and -Preview)
#     -Help / -?:          Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Hide,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Show,
	[switch]$Help
)

$TargetKB = 'KB5007651'

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Hide] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Show] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Hide                Hide KB5007651 from Windows Update (mutually exclusive with -Preview and -Show)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Report whether KB5007651 is currently hidden, visible, or not applicable, without changing anything" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Show                Show/unhide KB5007651 in Windows Update (mutually exclusive with -Hide and -Preview)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# Exactly one of -Hide, -Preview, or -Show is required
$actionCount = @($Hide, $Preview, $Show) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
if ($actionCount -ne 1) {
	Write-Host ""
	Write-Error "Exactly one of -Hide, -Preview, or -Show is required."
	exit 1
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Validate save path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# Check for/install third-party PSWindowsUpdate module, check for Windows Updates, print available updates to the console (also ignores hidden updates), and install them based on user-input
try {
	if (-not $NoConsoleOutput) { Write-Host "`nChecking for PSWindowsUpdate module..." -ForegroundColor Cyan }
	if (-not (Get-Module -ListAvailable -Name 'PSWindowsUpdate')) {
		if (-not $NoConsoleOutput) { Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow }
		Install-Module PSWindowsUpdate -Repository PSGallery -Force -SkipPublisherCheck -ErrorAction Stop
		if (-not $NoConsoleOutput) { Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green }
	}
	else {
		if (-not $NoConsoleOutput) { Write-Host "PSWindowsUpdate module already installed." -ForegroundColor Green }
	}
	Import-Module PSWindowsUpdate -ErrorAction Stop
}
catch {
	$errorMessage = "Failed to install or import PSWindowsUpdate: $($_.Exception.Message)"
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

# Perform the requested action
try {
	if ($Preview) {
		$hiddenMatch = Get-WindowsUpdate -KBArticleID $TargetKB -IsHidden -ErrorAction SilentlyContinue
		$visibleMatch = Get-WindowsUpdate -KBArticleID $TargetKB -ErrorAction SilentlyContinue

		if ($hiddenMatch) {
			$statusLine = "$ScriptName`: $TargetKB on $env:COMPUTERNAME is currently HIDDEN."
		}
		elseif ($visibleMatch) {
			$statusLine = "$ScriptName`: $TargetKB on $env:COMPUTERNAME is currently VISIBLE (not hidden)."
		}
		else {
			$statusLine = "$ScriptName`: $TargetKB does not apply to $env:COMPUTERNAME."
		}
	}
	elseif ($Hide) {
		$result = Hide-WindowsUpdate -KBArticleID $TargetKB -Confirm:$false -ErrorAction Stop
		if ($result) {
			$statusLine = "$ScriptName`: $TargetKB hidden on $env:COMPUTERNAME."
		}
		else {
			$statusLine = "$ScriptName`: $TargetKB does not apply to $env:COMPUTERNAME, nothing to hide."
		}
	}
	else {
		$result = Show-WindowsUpdate -KBArticleID $TargetKB -Confirm:$false -ErrorAction Stop
		if ($result) {
			$statusLine = "$ScriptName`: $TargetKB unhidden on $env:COMPUTERNAME."
		}
		else {
			$statusLine = "$ScriptName`: $TargetKB does not apply to $env:COMPUTERNAME, nothing to show."
		}
	}

	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $statusLine -ForegroundColor Green
	}
}
catch {
	$errorMessage = "$ScriptName`: Failed to process $TargetKB`: $($_.Exception.Message)"
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

# Save results
if ($SaveResults) {
	try {
		[System.IO.File]::AppendAllText($SaveResults, "$statusLine`n")
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.