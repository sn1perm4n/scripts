# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script disables Windows Recall in Windows 11

# IMPORTANT: Please read the DISM removal comment later in this script as it could directly impact you

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

$hadErrors = $false

Write-Host "`nDisabling Windows Recall..." -ForegroundColor Cyan

try {
	$recallPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
	New-Item -Path $recallPath -Force | Out-Null
	New-ItemProperty -Path $recallPath -Name "DisableAIDataAnalysis" -Type DWord -Value 1 -Force | Out-Null
	New-ItemProperty -Path $recallPath -Name "AllowRecallEnablement" -Type DWord -Value 0 -Force | Out-Null
	Write-Host "Windows Recall disabled." -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Warning "Windows Recall section failed: $($_.Exception.Message)"
	$hadErrors = $true
}

# OPTIONAL: Remove the Recall optional feature entirely (goes further than the policy-level disable above)
# IMPORTANT: THIS REQUIRES A RESTART AND ONLY APPLIES ON COPILOT+ PCS WHERE RECALL IS PRESENT. IF YOU
# WANT TO GO BEYOND THE POLICY-LEVEL DISABLE AND REMOVE THE FEATURE'S PAYLOAD FROM THE SYSTEM, UNCOMMENT
# THE LINE BELOW. TO REVERSE, RUN: Dism /Online /Enable-Feature /FeatureName:"Recall"
# Dism /Online /Disable-Feature /FeatureName:"Recall" /NoRestart

# Summary
if ($hadErrors) {
	Write-Host ""
	Write-Error "$ScriptName`: Windows Recall disabled with errors — some settings may not have taken effect. A reboot is required."
	exit 1
}
else {
	Write-Host "`n$ScriptName`: Windows Recall disabled successfully. A reboot is required." -ForegroundColor Green
	exit 0
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.