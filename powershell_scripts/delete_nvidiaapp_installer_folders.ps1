# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script deletes specific directories and their contents:
# "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer"
# "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer2"

#Requires -RunAsAdministrator

# Get the script name for usage/help output
$ScriptName = Split-Path $PSCommandPath -Leaf

# Specify the directories to delete
$programdataNvidiaappInstallerFolder = "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer"
$programdataNvidiaappInstaller2Folder = "C:\ProgramData\NVIDIA Corporation\NVIDIA app\Installer2"

$totalBytesFreed = 0
$deletedCount = 0

# Check if the Installer directory exists before attempting to delete it
Write-Host "`nChecking '$programdataNvidiaappInstallerFolder'..." -ForegroundColor Cyan
if (Test-Path -Path $programdataNvidiaappInstallerFolder -PathType Container) {
	try {
		$folderSize = (Get-ChildItem -Path $programdataNvidiaappInstallerFolder -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $folderSize) { $folderSize = 0 }
		Remove-Item -Path $programdataNvidiaappInstallerFolder -Recurse -Force -ErrorAction Stop
		$totalBytesFreed += $folderSize
		$deletedCount++
		Write-Host "Deleted '$programdataNvidiaappInstallerFolder'." -ForegroundColor Green
	}
	catch {
		Write-Host ""
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
		$folderSize = (Get-ChildItem -Path $programdataNvidiaappInstaller2Folder -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
		if (-not $folderSize) { $folderSize = 0 }
		Remove-Item -Path $programdataNvidiaappInstaller2Folder -Recurse -Force -ErrorAction Stop
		$totalBytesFreed += $folderSize
		$deletedCount++
		Write-Host "Deleted '$programdataNvidiaappInstaller2Folder'." -ForegroundColor Green
	}
	catch {
		Write-Host ""
		Write-Error "Failed to delete '$programdataNvidiaappInstaller2Folder': $($_.Exception.Message)"
	}
}
else {
	Write-Host "Folder '$programdataNvidiaappInstaller2Folder' does not exist." -ForegroundColor Yellow
}

# Summary
$totalFreedMB = [math]::Round($totalBytesFreed / 1MB, 2)
$totalFreedGB = [math]::Round($totalBytesFreed / 1GB, 2)
$freedDisplay = if ($totalBytesFreed -ge 1GB) { "$totalFreedGB GB" } else { "$totalFreedMB MB" }
$folderWord = if ($deletedCount -eq 1) { "folder" } else { "folders" }

if ($deletedCount -gt 0) {
	Write-Host "`n$ScriptName`: $deletedCount $folderWord deleted, $freedDisplay freed." -ForegroundColor Green
}
else {
	Write-Host "`n$ScriptName`: No folders deleted." -ForegroundColor Yellow
}

exit 0

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.