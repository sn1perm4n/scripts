# This script stops and disables various unnecessary services I don't use in Windows 11 and must be run as Administrator, which requires the following:
# 1. Create a shortcut to the .ps1 file, set the "Target" field to C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\Users\<PROFILE>\Scripts\disable_windows11_services.ps1"
# 2. Enable "Run as administrator" in the Shortcut tab -> Advanced)
# I strongly recommend creating a backup of your existing service settings before running this script. This way if something breaks you'll be able to figure out what changed and revert accordingly.
# Instructions:
# 1. Open PowerShell and type the following:
# 2. Get-Service | Select-Object Name, Status, StartType | Out-File -FilePath C:\Users\<PROFILE>\Desktop\Service_Status.txt
# NOTE: Substitute <PROFILE> with whatever your username is.
#Requires -RunAsAdministrator

# Ensure script runs as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal `
	([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator
)) {
	Write-Host "Please run this script as Administrator. Press any key to exit..." -ForegroundColor Red
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit 1
}

# AssignedAccessManagerSvc (AssignedAccessManager Service)
Stop-Service -Name AssignedAccessManagerSvc -Force -ErrorAction Stop
Write-Host "Service AssignedAccessManagerSvc stopped successfully."
Set-Service -Name AssignedAccessManagerSvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service AssignedAccessManagerSvc startup type set to Disabled."

# BDESVC (BitLocker Drive Encryption Service)
Stop-Service -Name BDESVC -Force -ErrorAction Stop
Write-Host "Service BDESVC stopped successfully."
Set-Service -Name BDESVC -StartupType Disabled -ErrorAction Stop
Write-Host "Service BDESVC startup type set to Disabled."

# DiagTrack (Connected User Experiences and Telemetry)
Stop-Service -Name DiagTrack -Force -ErrorAction Stop
Write-Host "Service DiagTrack stopped successfully."
Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction Stop
Write-Host "Service DiagTrack startup type set to Disabled."

# dmwappushservice (Device Management Wireless Application Protocol (WAP) Push message Routing Service)
Stop-Service -Name dmwappushservice -Force -ErrorAction Stop
Write-Host "Service dmwappushservice stopped successfully."
Set-Service -Name dmwappushservice -StartupType Disabled -ErrorAction Stop
Write-Host "Service dmwappushservice startup type set to Disabled."

# WdiServiceHost (Diagnostic Service Host)
Stop-Service -Name WdiServiceHost -Force -ErrorAction Stop
Write-Host "Service WdiServiceHost stopped successfully."
Set-Service -Name WdiServiceHost -StartupType Disabled -ErrorAction Stop
Write-Host "Service WdiServiceHost startup type set to Disabled."

# DialogBlockingService (DialogBlockingService)
Stop-Service -Name DialogBlockingService -Force -ErrorAction Stop
Write-Host "Service DialogBlockingService stopped successfully."
Set-Service -Name DialogBlockingService -StartupType Disabled -ErrorAction Stop
Write-Host "Service DialogBlockingService startup type set to Disabled."

# MapsBroker (Downloaded Maps Manager)
Stop-Service -Name MapsBroker -Force -ErrorAction Stop
Write-Host "Service MapsBroker stopped successfully."
Set-Service -Name MapsBroker -StartupType Disabled -ErrorAction Stop
Write-Host "Service MapsBroker startup type set to Disabled."

# lfsvc (Geolocation Service)
Stop-Service -Name lfsvc -Force -ErrorAction Stop
Write-Host "Service lfsvc stopped successfully."
Set-Service -Name lfsvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service lfsvc startup type set to Disabled."

# SharedAccess (Internet Connection Sharing (ICS)
Stop-Service -Name SharedAccess -Force -ErrorAction Stop
Write-Host "Service SharedAccess stopped successfully."
Set-Service -Name SharedAccess -StartupType Disabled -ErrorAction Stop
Write-Host "Service SharedAccess startup type set to Disabled."

# AppVClient (Microsoft App-V Client)
Stop-Service -Name AppVClient -Force -ErrorAction Stop
Write-Host "Service AppVClient stopped successfully."
Set-Service -Name AppVClient -StartupType Disabled -ErrorAction Stop
Write-Host "Service AppVClient startup type set to Disabled."

# MsKeyboardFilter (Microsoft Keyboard Filter)
Stop-Service -Name MsKeyboardFilter -Force -ErrorAction Stop
Write-Host "Service MsKeyboardFilter stopped successfully."
Set-Service -Name MsKeyboardFilter -StartupType Disabled -ErrorAction Stop
Write-Host "Service MsKeyboardFilter startup type set to Disabled."

# NetTcpPortSharing (Net.Tcp Port Sharing Service)
Stop-Service -Name NetTcpPortSharing -Force -ErrorAction Stop
Write-Host "Service NetTcpPortSharing stopped successfully."
Set-Service -Name NetTcpPortSharing -StartupType Disabled -ErrorAction Stop
Write-Host "Service NetTcpPortSharing startup type set to Disabled."

# Netlogon (Netlogon)
Stop-Service -Name NetTcpPortSharing -Force -ErrorAction Stop
Write-Host "Service NetTcpPortSharing stopped successfully."
Set-Service -Name NetTcpPortSharing -StartupType Disabled -ErrorAction Stop
Write-Host "Service NetTcpPortSharing startup type set to Disabled."

# CscService (Offline Files)
Stop-Service -Name CscService -Force -ErrorAction Stop
Write-Host "Service CscService stopped successfully."
Set-Service -Name CscService -StartupType Disabled -ErrorAction Stop
Write-Host "Service CscService startup type set to Disabled."

# WpcMonSvc (Parental Controls)
Stop-Service -Name WpcMonSvc -Force -ErrorAction Stop
Write-Host "Service WpcMonSvc stopped successfully."
Set-Service -Name WpcMonSvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service WpcMonSvc startup type set to Disabled."

# PhoneSvc (Phone Service)
Stop-Service -Name PhoneSvc -Force -ErrorAction Stop
Write-Host "Service PhoneSvc stopped successfully."
Set-Service -Name PhoneSvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service PhoneSvc startup type set to Disabled."

# WPDBusEnum (Portable Device Enumerator Service)
Stop-Service -Name WPDBusEnum -Force -ErrorAction Stop
Write-Host "Service WPDBusEnum stopped successfully."
Set-Service -Name WPDBusEnum -StartupType Disabled -ErrorAction Stop
Write-Host "Service WPDBusEnum startup type set to Disabled."

# RetailDemo (Retail Demo Service)
Stop-Service -Name RetailDemo -Force -ErrorAction Stop
Write-Host "Service RetailDemo stopped successfully."
Set-Service -Name RetailDemo -StartupType Disabled -ErrorAction Stop
Write-Host "Service RetailDemo startup type set to Disabled."

# RemoteAccess (Routing and Remote Access)
Stop-Service -Name RemoteAccess -Force -ErrorAction Stop
Write-Host "Service RemoteAccess stopped successfully."
Set-Service -Name RemoteAccess -StartupType Disabled -ErrorAction Stop
Write-Host "Service RemoteAccess startup type set to Disabled."

# seclogon (Secondary Logon)
Stop-Service -Name seclogon -Force -ErrorAction Stop
Write-Host "Service seclogon stopped successfully."
Set-Service -Name seclogon -StartupType Disabled -ErrorAction Stop
Write-Host "Service seclogon startup type set to Disabled."

# SensorService (Sensor Service)
Stop-Service -Name SensorService -Force -ErrorAction Stop
Write-Host "Service SensorService stopped successfully."
Set-Service -Name SensorService -StartupType Disabled -ErrorAction Stop
Write-Host "Service SensorService startup type set to Disabled."

# shpamsvc (Shared PC Account Manager)
Stop-Service -Name shpamsvc -Force -ErrorAction Stop
Write-Host "Service shpamsvc stopped successfully."
Set-Service -Name shpamsvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service shpamsvc startup type set to Disabled."

# ShellHWDetection (Shell Hardware Detection)
Stop-Service -Name ShellHWDetection -Force -ErrorAction Stop
Write-Host "Service ShellHWDetection stopped successfully."
Set-Service -Name ShellHWDetection -StartupType Disabled -ErrorAction Stop
Write-Host "Service ShellHWDetection startup type set to Disabled."

# UevAgentService (User Experience Virtualization Service)
Stop-Service -Name UevAgentService -Force -ErrorAction Stop
Write-Host "Service UevAgentService stopped successfully."
Set-Service -Name UevAgentService -StartupType Disabled -ErrorAction Stop
Write-Host "Service UevAgentService startup type set to Disabled."

# WalletService (WalletService)
Stop-Service -Name WalletService -Force -ErrorAction Stop
Write-Host "Service WalletService stopped successfully."
Set-Service -Name WalletService -StartupType Disabled -ErrorAction Stop
Write-Host "Service WalletService startup type set to Disabled."

# WbioSrvc (Windows Biometric Service)
Stop-Service -Name WbioSrvc -Force -ErrorAction Stop
Write-Host "Service WbioSrvc stopped successfully."
Set-Service -Name WbioSrvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service WbioSrvc startup type set to Disabled."

# wcncsvc (Windows Connect Now - Config Registrar)
Stop-Service -Name wcncsvc -Force -ErrorAction Stop
Write-Host "Service wcncsvc stopped successfully."
Set-Service -Name wcncsvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service wcncsvc startup type set to Disabled."

# WMPNetworkSvc (Windows Media Player Network Sharing Service)
Stop-Service -Name WMPNetworkSvc -Force -ErrorAction Stop
Write-Host "Service WMPNetworkSvc stopped successfully."
Set-Service -Name WMPNetworkSvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service WMPNetworkSvc startup type set to Disabled."

# icssvc (Windows Mobile Hotspot Service)
Stop-Service -Name icssvc -Force -ErrorAction Stop
Write-Host "Service icssvc stopped successfully."
Set-Service -Name icssvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service icssvc startup type set to Disabled."

# XboxGipSvc (Xbox Accessory Management Service)
Stop-Service -Name XboxGipSvc -Force -ErrorAction Stop
Write-Host "Service XboxGipSvc stopped successfully."
Set-Service -Name XboxGipSvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service XboxGipSvc startup type set to Disabled."

# XblAuthManager (Xbox Live Auth Manager)
Stop-Service -Name XblAuthManager -Force -ErrorAction Stop
Write-Host "Service XblAuthManager stopped successfully."
Set-Service -Name XblAuthManager -StartupType Disabled -ErrorAction Stop
Write-Host "Service XblAuthManager startup type set to Disabled."

# XblGameSave (Xbox Live Game Save)
Stop-Service -Name XblGameSave -Force -ErrorAction Stop
Write-Host "Service XblGameSave stopped successfully."
Set-Service -Name XblGameSave -StartupType Disabled -ErrorAction Stop
Write-Host "Service XblGameSave startup type set to Disabled."

# XboxNetApiSvc (Xbox Live Networking Service)
Stop-Service -Name XboxNetApiSvc -Force -ErrorAction Stop
Write-Host "Service XboxNetApiSvc stopped successfully."
Set-Service -Name XboxNetApiSvc -StartupType Disabled -ErrorAction Stop
Write-Host "Service XboxNetApiSvc startup type set to Disabled."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.