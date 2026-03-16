# This script shows hidden files and folders by making Registry changes and refreshing File Explorer to make the changes active

$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty -Path $registryPath -Name Hidden -Type DWord -Value 1 -Force
Set-ItemProperty -Path $registryPath -Name ShowSuperHidden -Type DWord -Value 1 -Force
$shell = New-Object -ComObject Shell.Application
$shell.Windows() | ForEach-Object { $_.Refresh() }

Write-Host "Successfully show 'Hidden Files and Folders'."

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.