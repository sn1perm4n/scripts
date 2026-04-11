# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script queries installed programs via WMI/CIM, deduplicates and sorts the output alphabetically, and optionally exports the results to a CSV file on the Desktop

# NOTE: Querying Win32_Product triggers a Windows Installer consistency check on all installed software. This can be slow and may trigger repair/reconfigure operations on some applications. This is a known limitation of Win32_Product.

# Optional CSV export path — leave empty or comment out to skip. $env:USERPROFILE resolves to C:\Users\<username>
$csvPath = "$env:USERPROFILE\Desktop\Installed_Programs_List.csv"

try {
	Write-Host "`nQuerying installed programs..." -ForegroundColor Cyan

	# Get installed programs
	if ($PSVersionTable.PSVersion.Major -ge 7) {
		# PowerShell 7+: use Get-CimInstance
		$programs = Get-CimInstance Win32_Product -ErrorAction Stop
	}
	else {
		# PowerShell 5: use Get-WmiObject
		$programs = Get-WmiObject Win32_Product -ErrorAction Stop
	}

	if (-not $programs) {
		Write-Host ""
		Write-Warning "No installed programs were found."
		exit 0
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
			Write-Host ""
			Write-Warning "CSV export skipped because the directory does not exist: $csvDirectory."
		}
		else {
			try {
				$programsClean | Export-Csv -Path $csvPath -NoTypeInformation -Force
				Write-Host "`nCSV exported to $csvPath." -ForegroundColor Green
			}
			catch {
				Write-Host ""
				Write-Warning "Failed to export CSV: $($_.Exception.Message)"
			}
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