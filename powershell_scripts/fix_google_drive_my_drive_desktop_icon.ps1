# GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script finds the latest installed Google Drive File Stream version folder and re-applies icon index 128 to the "My Drive" desktop shortcut, since Google Drive resets it to a blank icon on every update

# NOTE: Checks the 64-bit Program Files path first, falling back to Program Files (x86) if Drive File Stream is not found there

# NOTE2: Icon index 128 is assumed to be stable across Drive File Stream versions; if Google ever changes this, the hardcoded ",128" below will need updating

$ScriptName = Split-Path $PSCommandPath -Leaf

# Locate the latest installed Drive File Stream version folder
$basePaths = @(
	(Join-Path $env:ProgramFiles 'Google\Drive File Stream'),
	(Join-Path ${env:ProgramFiles(x86)} 'Google\Drive File Stream')
)

$driveFileStreamPath = $basePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $driveFileStreamPath) {
	Write-Host ""
	Write-Error "$ScriptName`: Could not find a Drive File Stream installation folder in Program Files or Program Files (x86)."
	exit 1
}

$versionFolders = Get-ChildItem -Path $driveFileStreamPath -Directory | Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' }

if (-not $versionFolders) {
	Write-Host ""
	Write-Error "$ScriptName`: No version folders found in '$driveFileStreamPath'."
	exit 1
}

Write-Host "`nFound Drive File Stream version(s) in '$driveFileStreamPath':" -ForegroundColor Cyan
$versionFolders | ForEach-Object { Write-Host "- $($_.Name)" }

$latestVersionFolder = $versionFolders | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
Write-Host "`nUsing latest version: $($latestVersionFolder.Name)" -ForegroundColor Green

$exePath = Join-Path $latestVersionFolder.FullName 'GoogleDriveFS.exe'

if (-not (Test-Path $exePath)) {
	Write-Host ""
	Write-Error "$ScriptName`: GoogleDriveFS.exe not found at '$exePath'."
	exit 1
}

# Locate the "My Drive" desktop shortcut
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'My Drive.lnk'

if (-not (Test-Path $shortcutPath)) {
	Write-Host ""
	Write-Error "$ScriptName`: 'My Drive' shortcut not found at '$shortcutPath'."
	exit 1
}

# Apply the correct icon (index 128) to the shortcut
try {
	$shell = New-Object -ComObject WScript.Shell
	$shortcut = $shell.CreateShortcut($shortcutPath)
	$shortcut.IconLocation = "$exePath,128"
	$shortcut.Save()
	Write-Host "`n$ScriptName`: Icon updated using $exePath" -ForegroundColor Green
}
catch {
	Write-Host ""
	Write-Error "$ScriptName`: Failed to update the shortcut icon: $($_.Exception.Message)"
	exit 1
}

# Refresh the icon cache so the change is visible immediately, without needing to sign out or restart Explorer
try {
	Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-show' -NoNewWindow -Wait -ErrorAction Stop
}
catch {
	Write-Host ""
	Write-Warning "$ScriptName`: Could not refresh the icon cache automatically: $($_.Exception.Message). You may need to sign out and back in to see the change."
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.