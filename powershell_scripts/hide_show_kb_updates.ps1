# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script hides, shows, or reports the visibility of a specified Windows Update KB, useful now that Microsoft is deprecating the wushowhide.diagcab tool

# NOTE: Both hidden and visible updates are listed to console for context, since the target -KB may not currently be offered at all

# Optional flags:
#     -Hide:               Hide the specified -KB from Windows Update (mutually exclusive with -Preview and -Show)
#     -KB <KBxxxxxxx>:     The KB article ID to hide, show, or check (i.e. -KB "KB5007651")
#     -NoConsoleOutput:    Suppress console output (requires -SaveResults)
#     -Preview:            Report whether the specified -KB is currently hidden, visible, or not applicable, without changing anything
#     -SaveResults <PATH>: Save results to a text file (appends if file exists)
#     -Show:               Show/unhide the specified -KB in Windows Update (mutually exclusive with -Hide and -Preview)
#     -Help / -?:          Display this help message

#Requires -RunAsAdministrator

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$Hide,
	[string]$KB,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Show,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Hide] [-KB <KBxxxxxxx>] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Show] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Hide                Hide the specified -KB from Windows Update (mutually exclusive with -Preview and -Show)" -ForegroundColor Cyan
	Write-Host "  -KB <KBxxxxxxx>      The KB article ID to hide, show, or check (i.e. -KB ""KB5007651"")" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview             Report whether the specified -KB is currently hidden, visible, or not applicable, without changing anything" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a text file (appends if file exists)" -ForegroundColor Cyan
	Write-Host "  -Show                Show/unhide the specified -KB in Windows Update (mutually exclusive with -Hide and -Preview)" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -KB is required
if (-not $KB) {
	Write-Host ""
	Write-Error "-KB is required."
	exit 1
}

# -KB must be in the format KBxxxxxxx
if ($KB -notmatch '^KB\d+$') {
	Write-Host ""
	Write-Error "-KB must be in the format 'KBxxxxxxx' (i.e. 'KB5007651')."
	exit 1
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

	# Write the hostname as a header line the first time this file is created, so a fleet of per-machine files can be identified at a glance
	if (-not (Test-Path $SaveResults)) {
		try {
			[System.IO.File]::AppendAllText($SaveResults, "$env:COMPUTERNAME`:`n")
		}
		catch {
			Write-Host ""
			Write-Warning "Could not write hostname header to '$SaveResults': $($_.Exception.Message)"
		}
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

# List all visible and hidden updates for context, then determine the target -KB's current status
try {
	if (-not $NoConsoleOutput) { Write-Host "`nChecking for available and hidden Windows updates..." -ForegroundColor Cyan }

	$visibleUpdates = Get-WindowsUpdate -ErrorAction SilentlyContinue
	$hiddenUpdates = Get-WindowsUpdate -IsHidden -ErrorAction SilentlyContinue

	if (-not $NoConsoleOutput) {
		Write-Host "`nAvailable (visible) updates:" -ForegroundColor Yellow
		if ($visibleUpdates) {
			$visibleUpdates | ForEach-Object { Write-Host "- $($_.KB): $($_.Title)" }
		}
		else {
			Write-Host "(none)"
		}

		Write-Host "`nHidden updates:" -ForegroundColor Yellow
		if ($hiddenUpdates) {
			$hiddenUpdates | ForEach-Object { Write-Host "- $($_.KB): $($_.Title)" }
		}
		else {
			Write-Host "(none)"
		}
	}

	$visibleMatch = $visibleUpdates | Where-Object { $_.KB -eq $KB }
	$hiddenMatch = $hiddenUpdates | Where-Object { $_.KB -eq $KB }

	if ($Preview) {
		if ($hiddenMatch) {
			$statusLine = "$ScriptName`: $KB on $env:COMPUTERNAME is currently HIDDEN."
		}
		elseif ($visibleMatch) {
			$statusLine = "$ScriptName`: $KB on $env:COMPUTERNAME is currently VISIBLE (not hidden)."
		}
		else {
			$statusLine = "$ScriptName`: $KB does not apply to $env:COMPUTERNAME."
		}
	}
	elseif ($Hide) {
		if (-not $visibleMatch) {
			$statusLine = "$ScriptName`: $KB does not apply to $env:COMPUTERNAME, nothing to hide."
		}
		else {
			Hide-WindowsUpdate -KBArticleID $KB -Confirm:$false -ErrorAction Stop
			$statusLine = "$ScriptName`: $KB hidden on $env:COMPUTERNAME."
		}
	}
	else {
		if (-not $hiddenMatch) {
			$statusLine = "$ScriptName`: $KB does not apply to $env:COMPUTERNAME, nothing to show."
		}
		else {
			Show-WindowsUpdate -KBArticleID $KB -Confirm:$false -ErrorAction Stop
			$statusLine = "$ScriptName`: $KB unhidden on $env:COMPUTERNAME."
		}
	}

	if (-not $NoConsoleOutput) {
		Write-Host ""
		Write-Host $statusLine -ForegroundColor Green
	}
}
catch {
	$errorMessage = "$ScriptName`: Failed to process $KB`: $($_.Exception.Message)"
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

# Save results (target -KB status line only, not the full available/hidden list, so multi-machine logs stay compact and mergeable)
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