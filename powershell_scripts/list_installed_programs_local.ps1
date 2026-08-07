# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script queries installed programs via CIM, deduplicates and sorts the output alphabetically, and optionally exports the results to a CSV file

# NOTE: Querying Win32_Product triggers a Windows Installer consistency check on all installed software. This can be slow and may trigger repair/reconfigure operations on some applications. This is a known limitation of Win32_Product.

# NOTE: To see all available column names that can be passed to -Columns, run the following command:
# Get-CimInstance Win32_Product | Select-Object -First 1 | Get-Member -MemberType Property | Select-Object Name

# Optional flags:
#     -CaseSensitive: Enables case-sensitive filtering (requires -Filter)
#     -Columns <string[]>: Specify which columns to display and export (default: Name, Vendor, Version)
#     -Exact: Match only programs whose name equals the filter text exactly (requires -Filter)
#     -Filter <string>: Filter results to only show programs whose name contains the specified string (case-insensitive by default; see -CaseSensitive and -Exact)
#     -NoConsoleOutput: Suppress all console output (requires -SaveResults)
#     -SaveResults <PATH>: Save results to a CSV file (i.e. -SaveResults "C:\output.csv")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[switch]$CaseSensitive,
	[string[]]$Columns,
	[switch]$Exact,
	[string]$Filter,
	[switch]$NoConsoleOutput,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-CaseSensitive] [-Columns <string[]>] [-Exact] [-Filter <string>] [-NoConsoleOutput] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -CaseSensitive       Enables case-sensitive filtering (requires -Filter)" -ForegroundColor Cyan
	Write-Host "  -Columns <cols>      Specify which columns to display and export (default: Name, Vendor, Version)" -ForegroundColor Cyan
	Write-Host "                       Example: -Columns Name, Version, InstallDate" -ForegroundColor Cyan
	Write-Host "                       Available: Name, Vendor, Version, InstallDate, InstallLocation, InstallSource," -ForegroundColor Cyan
	Write-Host "                                  Caption, Description, IdentifyingNumber, Language, PackageName" -ForegroundColor Cyan
	Write-Host "  -Exact               Match only programs whose name equals the filter text exactly (requires -Filter)" -ForegroundColor Cyan
	Write-Host "  -Filter <string>     Filter results to only show programs whose name contains the specified string" -ForegroundColor Cyan
	Write-Host "                       (case-insensitive by default; see -CaseSensitive and -Exact)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress all console output (requires -SaveResults)" -ForegroundColor Cyan
	Write-Host "  -SaveResults <PATH>  Save results to a CSV file (i.e. -SaveResults ""C:\output.csv"")" -ForegroundColor Cyan
	Write-Host "  -Help                Display this help message" -ForegroundColor Cyan
	Write-Host ""  # extra newline for readability
	exit 0
}

# Default columns if not specified
$defaultColumns = @("Name", "Vendor", "Version")
$selectedColumns = if ($Columns) { $Columns } else { $defaultColumns }

# Valid Win32_Product properties for validation
$validColumns = @(
	"Name", "Vendor", "Version", "InstallDate", "InstallLocation",
	"InstallSource", "Caption", "Description", "IdentifyingNumber",
	"Language", "PackageName"
)

# Validate -Columns values
if ($Columns) {
	$invalidColumns = $Columns | Where-Object { $validColumns -notcontains $_ }
	if ($invalidColumns) {
		Write-Host ""
		Write-Error "Invalid -Columns value(s): $($invalidColumns -join ', '). Valid options are: $($validColumns -join ', ')"
		exit 1
	}
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

# -NoConsoleOutput requires -SaveResults, since without it there's nowhere to record results,
# and running the (potentially slow, side-effect-prone) Win32_Product query for no output at all is wasteful
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Error "-NoConsoleOutput requires -SaveResults."
	exit 1
}

try {
	if (-not $NoConsoleOutput) { Write-Host "`nQuerying installed programs..." -ForegroundColor Cyan }

	# Get installed programs
	$programs = Get-CimInstance Win32_Product -ErrorAction Stop

	if (-not $programs) {
		$warningMessage = "$ScriptName`: No installed programs were found."
		if (-not $NoConsoleOutput) {
			Write-Host ""
			Write-Warning $warningMessage
		}
		if ($SaveResults) {
			try {
				[System.IO.File]::WriteAllText($SaveResults, $warningMessage)
			}
			catch {
				Write-Host ""
				Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
			}
		}
		exit 0
	}

	# Select, sort, and optionally filter
	$programsClean = $programs |
		Select-Object $selectedColumns |
		Sort-Object Name

	if ($Filter) {
		$programsClean = $programsClean | Where-Object {
			if ($Exact) {
				if ($CaseSensitive) { $_.Name -ceq $Filter } else { $_.Name -ieq $Filter }
			}
			else {
				if ($CaseSensitive) { $_.Name -clike "*$Filter*" } else { $_.Name -ilike "*$Filter*" }
			}
		}
		if (-not $programsClean) {
			$warningMessage = "$ScriptName`: No programs found matching filter: '$Filter'"
			if (-not $NoConsoleOutput) {
				Write-Host ""
				Write-Warning $warningMessage
			}
			if ($SaveResults) {
				try {
					[System.IO.File]::WriteAllText($SaveResults, $warningMessage)
				}
				catch {
					Write-Host ""
					Write-Warning "Could not save results to '$SaveResults': $($_.Exception.Message)"
				}
			}
			exit 0
		}
	}

	# Output to console
	if (-not $NoConsoleOutput) {
		$programsClean | Format-Table -AutoSize | Out-String -Stream | Where-Object { $_ -ne '' } | Write-Host
	}

	# Save results to CSV if requested
	if ($SaveResults) {
		try {
			$programsClean | Export-Csv -Path $SaveResults -NoTypeInformation -Force
			if (-not $NoConsoleOutput) { Write-Host "$ScriptName`: Results saved to CSV file: $SaveResults" -ForegroundColor Green }
		}
		catch {
			# This warning covers a failure to write to -SaveResults itself, so there's no file left to redirect it into - it always prints to console, even with -NoConsoleOutput, since otherwise it would vanish with no record anywhere
			Write-Host ""
			Write-Warning "Failed to export CSV: $($_.Exception.Message)"
		}
	}

	if (-not $NoConsoleOutput) { Write-Host "`n$ScriptName`: Installed program query completed successfully." -ForegroundColor Green }
}
catch {
	Write-Host ""
	Write-Error "An error occurred while querying installed programs: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.