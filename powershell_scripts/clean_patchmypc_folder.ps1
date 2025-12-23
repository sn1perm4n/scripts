# This script deletes all but the most recent file and folder in a specific directory
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
$programdataPatchmypcFolder = 'C:\ProgramData\Patch My PC\Patch My PC Home Updater\updates'

# --- Guard clauses ---
if (-not (Test-Path $programdataPatchmypcFolder)) {
	Write-Warning "The directory '$programdataPatchmypcFolder' does not exist."
	exit
}

if (-not (Get-ChildItem -Path $programdataPatchmypcFolder -Force)) {
	Write-Warning "The directory '$programdataPatchmypcFolder' is empty."
	exit
}

try {
	$deleted = $false
	# Keep only the most recent file
	$files = Get-ChildItem -Path $programdataPatchmypcFolder -File
	if ($files.Count -gt 0) {
		$latestFile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		Write-Host "Keeping file: $($latestFile.FullName)"
		if ($files.Count -gt 1) {
			$files | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
				ForEach-Object {
					Write-Host "Deleting file: $($_.FullName)"
					Remove-Item $_.FullName -Force
					$deleted = $true
				}
		}
	}
	# Keep only the most recent folder
	$folders = Get-ChildItem -Path $programdataPatchmypcFolder -Directory
	if ($folders.Count -gt 0) {
		$latestFolder = $folders | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		Write-Host "Keeping folder: $($latestFolder.FullName)"
		if ($folders.Count -gt 1) {
			$folders | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
				ForEach-Object {
					Write-Host "Deleting folder: $($_.FullName)"
					Remove-Item $_.FullName -Recurse -Force
					$deleted = $true
				}
		}
	}

	if ($deleted) {
		Write-Host "Successfully deleted all but the most recent file and folder in '$programdataPatchmypcFolder'."
	}
	else {
		Write-Host "No deletions were necessary."
	}
}
catch {
	Write-Error "An error occurred while trying to delete items in '$programdataPatchmypcFolder': $($_.Exception.Message)."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.