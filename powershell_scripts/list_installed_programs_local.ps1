# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script queries Installed Programs and deduplicates the final output
# Query installed programs using WMI/CIM. Output is sorted alphabetically by Name and displayed on screen.
# Optionally export to CSV by setting $csvPath (ENABLED BY DEFAULT, MAKE SURE THE PATH IS CORRECT).

#Requires -RunAsAdministrator

# Optional CSV path (leave empty to skip export)
# $csvPath = ""  # Uncomment this line to disable CSV export
$csvPath = "C:\Users\PROFILE\Desktop\Installed_Programs_List.csv"

try {
	Write-Host "`nQuerying installed programs..." -ForegroundColor Cyan

	# Get installed programs
	if ($PSVersionTable.PSVersion.Major -ge 7) {
		# PowerShell 7+: use Get-CimInstance
		$programs = Get-CimInstance Win32_Product -ErrorAction Stop
	} else {
		# PowerShell 5: use Get-WmiObject
		$programs = Get-WmiObject Win32_Product -ErrorAction Stop
	}

	if (-not $programs) {
		Write-Warning "`nNo installed programs were found."
		return
	}

	# Select required properties and sort alphabetically: InstallDate and InstallLocation may also be useful
	$programsClean = $programs |
		Select-Object Name, Vendor, Version |
		Sort-Object Name

	# Output to screen
	$programsClean | Format-Table -AutoSize

	# Optional export to CSV
	if ($csvPath -and $csvPath.Trim() -ne "") {
		$csvDirectory = Split-Path -Path $csvPath -Parent

		if (-not (Test-Path -Path $csvDirectory)) {
			Write-Warning "CSV export skipped because the directory does not exist: $csvDirectory."
		} else {
			try {
				$programsClean | Export-Csv -Path $csvPath -NoTypeInformation -Force
				Write-Host "`nCSV exported to $csvPath." -ForegroundColor Green
			} catch {
				Write-Warning "Failed to export CSV: $($_.Exception.Message)"
			}
		}
	}

	Write-Host "`nInstalled program query completed successfully." -ForegroundColor Green

} catch {
	Write-Error "An error occurred while querying installed programs: $($_.Exception.Message)"
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.
