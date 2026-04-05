# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes specific directories and their contents:
# "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer"
# "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer2"

#Requires -RunAsAdministrator

# Specify the directories to delete
$programdataNvidiaappInstallerFolder = "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer"
$programdataNvidiaappInstaller2Folder = "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer2"

# Check if the Installer directory exists before attempting to delete it
Write-Host "`nChecking '$programdataNvidiaappInstallerFolder'..." -ForegroundColor Cyan
if (Test-Path -Path $programdataNvidiaappInstallerFolder -PathType Container) {
	try {
		Remove-Item -Path $programdataNvidiaappInstallerFolder -Recurse -Force -ErrorAction Stop
		Write-Host "Deleted '$programdataNvidiaappInstallerFolder'." -ForegroundColor Green
	}
	catch {
		Write-Error "Failed to delete '$programdataNvidiaappInstallerFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Host "Folder '$programdataNvidiaappInstallerFolder' does not exist." -ForegroundColor Yellow
}

# Check if the Installer2 directory exists before attempting to delete it
Write-Host "`nChecking '$programdataNvidiaappInstaller2Folder'..." -ForegroundColor Cyan
if (Test-Path -Path $programdataNvidiaappInstaller2Folder -PathType Container) {
	try {
		Remove-Item -Path $programdataNvidiaappInstaller2Folder -Recurse -Force -ErrorAction Stop
		Write-Host "Deleted '$programdataNvidiaappInstaller2Folder'." -ForegroundColor Green
	}
	catch {
		Write-Error "Failed to delete '$programdataNvidiaappInstaller2Folder': $($_.Exception.Message)"
	}
}
else {
	Write-Host "Folder '$programdataNvidiaappInstaller2Folder' does not exist." -ForegroundColor Yellow
}

Write-Host "`nNVIDIA app installer folder cleanup complete." -ForegroundColor Green

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.