# This script deletes the contents of a specific folder
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

# Specify the directory to process
$appleComputerInstallerCacheFolder = 'C:\ProgramData\Apple Computer\Installer Cache'

# Check if the directory exists
if (Test-Path -Path $appleComputerInstallerCacheFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $appleComputerInstallerCacheFolder -Force
		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$appleComputerInstallerCacheFolder' exists but is empty."
			return
		}
		# Output what will be deleted
		Write-Host "Deleting the following items:"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }
		# Delete all files/folders within the directory
		Remove-Item -Path "$appleComputerInstallerCacheFolder\*" -Recurse -Force
		Write-Host "Successfully deleted the contents of '$appleComputerInstallerCacheFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$appleComputerInstallerCacheFolder': $($_.Exception.Message)"
	}
}
else {
	Write-Warning "The directory '$appleComputerInstallerCacheFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.