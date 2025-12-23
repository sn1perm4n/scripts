# This script is a parameterized version that deletes the contents of a specified directory. It can be re-used for any directory by doing the following:
# Usage: .\clean_folder.ps1 -targetFolder "C:\ProgramData\Apple Computer\Installer Cache"
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

param (
	[Parameter(Mandatory = $true)]
	[string]$targetFolder
)

# Check if the directory exists
if (Test-Path -Path $targetFolder) {
	try {
		# Check if the directory has any items
		$items = Get-ChildItem -Path $targetFolder -Force

		# Guard clause that activates and exits if the directory is empty
		if (-not $items) {
			Write-Warning "The directory '$targetFolder' exists but is empty."
			return
		}

		# Output what will be deleted
		Write-Host "Deleting the following items from '$targetFolder':"
		$items | ForEach-Object { Write-Host " - $($_.FullName)" }

		# Delete all files and folders within the directory
		$items | Remove-Item -Recurse -Force

		Write-Host "Successfully deleted the contents of '$targetFolder'."
	}
	catch {
		Write-Error "An error occurred while trying to delete items in '$targetFolder': $($_.Exception.Message)."
	}
}
else {
	Write-Warning "The directory '$targetFolder' does not exist."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.