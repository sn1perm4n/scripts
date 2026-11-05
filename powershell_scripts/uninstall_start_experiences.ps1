# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script removes Microsoft Start Experiences App

# NOTE: Without -AllUsers, only the current user's copy of the Start Experiences App is checked and removed, so admin rights are not required; -AllUsers covers every account on the machine and requires an elevated session, which is also what a deployment tool running as SYSTEM needs since SYSTEM has no copy of its own

# NOTE2: -AllUsers searches for the bundle package first (the form the all-users removal guidance uses) and falls back to a plain package search if none is found

# Optional flags:
#     -AllUsers:             Remove the Start Experiences App for every user account on the machine (requires an elevated session)
#     -NoConsoleOutput:      Suppress console output (requires -SaveResults)
#     -Preview:              Show whether the Start Experiences App is installed and what would be removed without making any changes
#     -SaveResults <PATH>:   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)
#     -Help / -?:            Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$AllUsers,
	[switch]$NoConsoleOutput,
	[switch]$Preview,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-AllUsers] [-NoConsoleOutput] [-Preview] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -AllUsers             Remove the Start Experiences App for every user account on the machine (requires an elevated session)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput      Suppress console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -Preview              Show whether the Start Experiences App is installed and what would be removed without making any changes" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>   Save results to a text file (appends if file exists, with a hostname header identifying the machine the script was run from)" -ForegroundColor Cyan
	Write-Host "  -Help                 Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

# Validate the save path if specified
if ($SaveResults) {
	$saveDir = Split-Path $SaveResults -Parent
	if ($saveDir -and -not (Test-Path $saveDir)) {
		Write-Host ""
		Write-Error "The directory for -SaveResults does not exist: '$saveDir'"
		exit 1
	}
}

# -AllUsers requires elevation, since removing a package for every account needs admin rights
if ($AllUsers) {
	$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	if (-not $isAdmin) {
		Write-Host ""
		Write-Error "-AllUsers requires an elevated PowerShell session."
		exit 1
	}
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

$resultLines = @()
$exitCode = 0
$packageName = "Microsoft.StartExperiencesApp"

$scopeText = "the current user"
if ($AllUsers) {
	$scopeText = "all users"
}

# Finds the installed Start Experiences App package(s) for the chosen scope
$findPackages = {
	if ($AllUsers) {
		$found = @(Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -Name $packageName)
		if (-not $found) {
			$found = @(Get-AppxPackage -AllUsers -Name $packageName)
		}
		$found
	}
	else {
		@(Get-AppxPackage -Name $packageName)
	}
}

if (-not $NoConsoleOutput) { Write-Host "`nChecking for Microsoft Start Experiences App..." -ForegroundColor Cyan }
$packages = @(& $findPackages)
$packageList = ($packages | ForEach-Object { $_.PackageFullName }) -join ", "

$summaryKind = "Info"
if ($Preview) {
	if ($packages.Count -eq 0) {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. Microsoft Start Experiences App is not installed for $scopeText. Nothing would be removed. No changes were made."
	}
	else {
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Preview complete. Microsoft Start Experiences App ($packageList) is installed and would be removed for $scopeText. No changes were made."
	}
}
elseif ($packages.Count -eq 0) {
	$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Microsoft Start Experiences App is not installed for $scopeText. Nothing to remove."
}
else {
	if (-not $NoConsoleOutput) { Write-Host "`nRemoving Microsoft Start Experiences App for $scopeText..." -ForegroundColor Cyan }

	try {
		foreach ($package in $packages) {
			if ($AllUsers) {
				Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
			}
			else {
				Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
			}
		}

		# Confirm the package is actually gone rather than trusting the removal call alone
		$remainingPackages = @(& $findPackages)
		if ($remainingPackages.Count -eq 0) {
			$summaryKind = "Success"
			$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Microsoft Start Experiences App successfully uninstalled for $scopeText."
		}
		else {
			$summaryKind = "Warning"
			$exitCode = 1
			$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Microsoft Start Experiences App removal finished, but $($remainingPackages.Count) package(s) are still installed for $scopeText."
		}
	}
	catch {
		$summaryKind = "Error"
		$exitCode = 1
		$summaryLine = "$ScriptName`: [$env:COMPUTERNAME] Failed to uninstall Microsoft Start Experiences App: $($_.Exception.Message)"
	}
}

if (-not $NoConsoleOutput) {
	switch ($summaryKind) {
		"Success" {
			Write-Host "`n$summaryLine" -ForegroundColor Green
		}
		"Warning" {
			Write-Host ""
			Write-Warning $summaryLine
		}
		"Error" {
			Write-Host ""
			Write-Error $summaryLine
		}
		default {
			Write-Host "`n$summaryLine" -ForegroundColor Yellow
		}
	}
}
$resultLines += $summaryLine

# Save results
if ($SaveResults) {
	try {
		$content = ($resultLines -join "`n") + "`n"
		[System.IO.File]::AppendAllText($SaveResults, $content)
		if (-not $NoConsoleOutput) { Write-Host "`nResults saved to: $SaveResults" -ForegroundColor Green }
	}
	catch {
		# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
		Write-Host ""
		Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
	}
}

exit $exitCode

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.