# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a user-supplied folder (and subfolders) for files that are blocked from running and then optionally unblocks them. Two practical examples would be C:\Tools\PsTools (or in my instance C:\Program Files (x86)\PsTools 2.51) and C:\Tools\unxutils. Admin is required to make changes to any file in one of the protected system folders. Delete everything from here down to "# Prompt the user for the folder to process" if you don't need the admin requirement.
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

# Prompt the user for the folder to process
$Path = Read-Host "Enter the directory to scan"

try {
	if (-not (Test-Path -Path $Path -PathType Container)) {
		throw "The specified path does not exist or is not a directory."
	}
}
catch {
	Write-Host "ERROR: $($_.Exception.Message)." -ForegroundColor Red
	return
}

# Scan the user-supplied folder
Write-Host "`nScanning directory: $Path" -ForegroundColor Cyan

try {
	$files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop
}
catch {
	Write-Host "ERROR enumerating files: $($_.Exception.Message)." -ForegroundColor Red
	return
}

$blockedFiles = @()
$checkErrors  = @()

foreach ($file in $files) {

	# Check for and record blocked files
	try {
		$null = Get-Item -Path $file.FullName -Stream Zone.Identifier -ErrorAction Stop
		$blockedFiles += $file
	}
	catch {
		# Ignore "stream not found" errors (means file is not blocked)
		if ($_.Exception.Message -notmatch "Zone.Identifier") {
			$checkErrors += [PSCustomObject]@{
				File  = $file.FullName
				Error = $_.Exception.Message
			}
		}
	}
}

if ($blockedFiles.Count -eq 0) {
	Write-Host "`nNo blocked files found." -ForegroundColor Green
	return
}

# Display all blocked file paths
$blockedFiles.FullName | Sort-Object

# Show summary and any check errors
Write-Host "Blocked files found: $($blockedFiles.Count)" -ForegroundColor Yellow

if ($checkErrors.Count -gt 0) {
	Write-Host "`nSome files could not be checked:" -ForegroundColor DarkYellow

	foreach ($err in $checkErrors) {
		Write-Host "File: $($err.File)"  -ForegroundColor Red
		Write-Host "Error: $($err.Error)" -ForegroundColor Red
	}
}

# Prompt the user to optionally unblock all files
$response = Read-Host "`nUnblock ALL listed files? (Y/N)"

if ($response -match '^[Yy]$') {

	$unblockErrors = @()

	foreach ($file in $blockedFiles) {

		try {
			Unblock-File -Path $file.FullName -ErrorAction Stop
		}
		catch {
			$unblockErrors += [PSCustomObject]@{
				File  = $file.FullName
				Error = $_.Exception.Message
			}
		}
	}
	# Unblock operation succeeded
	Write-Host "`nUnblock operation complete." -ForegroundColor Green

	# Unblock operation failed
	if ($unblockErrors.Count -gt 0) {
		Write-Host "`nSome files failed to unblock:" -ForegroundColor Yellow

		foreach ($err in $unblockErrors) {
			Write-Host "File: $($err.File)"  -ForegroundColor Red
			Write-Host "Error: $($err.Error)" -ForegroundColor Red
		}
	}
}
else {
	Write-Host "`nNo files were modified."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.