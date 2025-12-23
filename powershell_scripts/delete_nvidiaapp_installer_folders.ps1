# This script deletes specific directories and their contents
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

# Define the paths to the directories you want to delete
$programdataNvidiaappInstallerFolder = "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer"
$programdataNvidiaappInstaller2Folder = "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer2"

# Check if the Installer directory exists before attempting to delete it
if (Test-Path -Path $programdataNvidiaappInstallerFolder -PathType Container) {
	# Remove the folder and its contents recursively and without prompting for confirmation
	Remove-Item -Path $programdataNvidiaappInstallerFolder -Recurse -Force -ErrorAction SilentlyContinue
	Write-Host "Folder '$programdataNvidiaappInstallerFolder' and its contents have been deleted."
} else {
	Write-Host "Folder '$programdataNvidiaappInstallerFolder' does not exist."
}

# Check if the Installer2 directory exists before attempting to delete it
if (Test-Path -Path $programdataNvidiaappInstaller2Folder -PathType Container) {
	# Remove the folder and its contents recursively and without prompting for confirmation
	Remove-Item -Path $programdataNvidiaappInstaller2Folder -Recurse -Force -ErrorAction SilentlyContinue
	Write-Host "Folder '$programdataNvidiaappInstaller2Folder' and its contents have been deleted."
} else {
	Write-Host "Folder '$programdataNvidiaappInstaller2Folder' does not exist."
}

Write-Host "Successfully deleted '$programdataNvidiaappInstallerFolder' and 
$programdataNvidiaappInstaller2Folder'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.
