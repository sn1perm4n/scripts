# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables Hibernation
# Check Hibernation status via the registry (preferred for scripting):
# Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled
# Or alternately, check available sleep states using PowerCfg in the Command Prompt:
# powercfg /a
# - If "Hibernate" appears under "The following sleep states are available", it is enabled
# - If it appears under "not available" or is missing, it is disabled

#Requires -RunAsAdministrator

try {
	# Check current Hibernation status
	Write-Host "`nChecking Hibernation status..." -ForegroundColor Cyan
	$hibernationEnabled = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled).HibernateEnabled -eq 1

	if (-not $hibernationEnabled) {
		Write-Host "`nHibernation is already disabled." -ForegroundColor Yellow
	}
	else {
		# Disable Hibernation
		Write-Host "`nDisabling Hibernation..." -ForegroundColor Cyan
		powercfg.exe /hibernate off

		# Verify the change
		$hibernationEnabled = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power -Name HibernateEnabled).HibernateEnabled -eq 1

		if (-not $hibernationEnabled) {
			Write-Host "`nHibernation successfully disabled." -ForegroundColor Green
		}
		else {
			Write-Host "`nHibernation disable verification failed." -ForegroundColor Yellow
		}
	}
}
catch {
	Write-Host ""
	Write-Error "An error occurred while managing Hibernation: $($_.Exception.Message)"
	exit 1
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.