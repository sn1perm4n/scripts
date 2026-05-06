# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script queries installed programs via CIM, deduplicates and sorts the output alphabetically, and optionally exports the results to a CSV file

# NOTE: Querying Win32_Product triggers a Windows Installer consistency check on all installed software. This can be slow and may trigger repair/reconfigure operations on some applications. This is a known limitation of Win32_Product.

# NOTE: To see all available column names that can be passed to -Columns, run the following command:
# Get-CimInstance Win32_Product | Select-Object -First 1 | Get-Member -MemberType Property | Select-Object Name

# Optional flags:
#     -Columns <string[]>: Specify which columns to display and export (default: Name, Vendor, Version)
#     -Filter <string>: Filter results to only show programs whose name contains the specified string (case-insensitive)
#     -NoConsoleOutput: Suppress table output to the console (useful when only saving to CSV via -SaveResults)
#     -SaveResults <PATH>: Save results to a CSV file (i.e. -SaveResults "C:\output.csv")
#     -Help / -?: Display this help message

[CmdletBinding(PositionalBinding=$false)]
param (
	[string[]]$Columns,
	[string]$Filter,
	[switch]$NoConsoleOutput,
	[string]$SaveResults,
	[switch]$Help
)

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Handle -Help immediately
if ($Help) {
	Write-Host "`nUsage:`n    .\$ScriptName [-Columns <string[]>] [-Filter <string>] [-NoConsoleOutput] [-SaveResults <PATH>] [-Help]" -ForegroundColor Cyan
	Write-Host "`nOptional flags:" -ForegroundColor Cyan
	Write-Host "  -Columns <cols>      Specify which columns to display and export (default: Name, Vendor, Version)" -ForegroundColor Cyan
	Write-Host "                       Example: -Columns Name, Version, InstallDate" -ForegroundColor Cyan
	Write-Host "                       Available: Name, Vendor, Version, InstallDate, InstallLocation, InstallSource," -ForegroundColor Cyan
	Write-Host "                                  Caption, Description, IdentifyingNumber, Language, PackageName" -ForegroundColor Cyan
	Write-Host "  -Filter <string>     Filter results to only show programs whose name contains the specified string (case-insensitive)" -ForegroundColor Cyan
	Write-Host "  -NoConsoleOutput     Suppress table output to the console (useful when only saving to CSV via -SaveResults)" -ForegroundColor Cyan
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

# Warn if -NoConsoleOutput is used without -SaveResults
if ($NoConsoleOutput -and -not $SaveResults) {
	Write-Host ""
	Write-Warning "-NoConsoleOutput was specified without -SaveResults. Results will not be displayed or saved."
}

try {
	Write-Host "`nQuerying installed programs..." -ForegroundColor Cyan

	# Get installed programs
	$programs = Get-CimInstance Win32_Product -ErrorAction Stop

	if (-not $programs) {
		Write-Host ""
		Write-Warning "No installed programs were found."
		exit 0
	}

	# Select, sort, and optionally filter
	$programsClean = $programs |
		Select-Object $selectedColumns |
		Sort-Object Name

	if ($Filter) {
		$programsClean = $programsClean | Where-Object { $_.Name -like "*$Filter*" }
		if (-not $programsClean) {
			Write-Host ""
			Write-Warning "No programs found matching filter: '$Filter'"
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
			Write-Host "Results saved to CSV file: $SaveResults" -ForegroundColor Green
		}
		catch {
			Write-Host ""
			Write-Warning "Failed to export CSV: $($_.Exception.Message)"
		}
	}

	Write-Host "`nInstalled program query completed successfully." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "An error occurred while querying installed programs: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.