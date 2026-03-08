# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script checks a single script or a folder of scripts for an extra . at the end of $($_.Exception.Message) and removes the period when there shouldn't be one (Write-Error and Write-Warning) [i.e. "$($_.Exception.Message)." becomes "$($_.Exception.Message)"]. A backup (.bak) is created for each modified script.
# Optional switch: -DryRun mode to preview changes without saving

param (
	[switch]$DryRun
)

# Prompt the user for a script or folder to process
$InputPath = Read-Host "`nEnter the full path to a script (.ps1) or a folder containing scripts"

# Check that the path exists (either file or folder)
if (-not (Test-Path -LiteralPath $InputPath)) {
	Write-Host ""
	Write-Error "Path '$InputPath' does not exist."
	exit
}

# Determine if input is a folder or a file
$Item = Get-Item -LiteralPath $InputPath
$IsFolder = $Item.PSIsContainer

# Initialize counter for modified files
$ModifiedCount = 0

# Gather files
if ($IsFolder) {
	$Files = Get-ChildItem -Path $InputPath -Filter *.ps1 -File -Recurse
} else {
	$Files = @($Item)  # wrap single file in array so foreach works
}

# Process each file
foreach ($File in $Files) {
	$FilePath = $File.FullName
	$DisplayPath = $FilePath
	$FileName = $File.Name
	$Lines = Get-Content -LiteralPath $FilePath
	$Modified = $false
	$FirstFixInFile = $true

	for ($i = 0; $i -lt $Lines.Count; $i++) {
		# Match Write-Error or Write-Warning lines with $($_.Exception.Message) immediately followed by a period
		if ($Lines[$i] -match '(Write-Error|Write-Warning).*?\$\(\$_\.Exception\.Message\)\.') {

			# Add a blank line and filename before the first fix of each file
			if ($FirstFixInFile) {
				Write-Host ""
				Write-Host $FileName -ForegroundColor Cyan
				$FirstFixInFile = $false
			}

			Write-Host ("Fixing line " + ($i + 1) + ":") -ForegroundColor Cyan
			Write-Host "    Original: $($Lines[$i])" -ForegroundColor Yellow

			# Remove the period
			$Lines[$i] = $Lines[$i] -replace '(\$\(\$_\.Exception\.Message\))\.', '$1'
			Write-Host "    Fixed   : $($Lines[$i])" -ForegroundColor Green

			$Modified = $true
		}
	}

	if ($Modified) {
		if ($DryRun) {
			Write-Host "`nDryRun: Changes detected in $DisplayPath (no modifications made)" -ForegroundColor Yellow
			$ModifiedCount++
		}
		else {
			# Create a backup
			Copy-Item -Path $FilePath -Destination "$FilePath.bak" -Force

			# Save modified file
			$ResolvedPath = (Resolve-Path $FilePath).Path
			$Lines | Set-Content -Path $ResolvedPath

			Write-Host "`n$FileName updated (backup saved as $DisplayPath.bak)" -ForegroundColor Green
			$ModifiedCount++
		}
	}
}

# Summary
if ($DryRun) {
	Write-Host "`nScan complete. $ModifiedCount file(s) would be modified." -ForegroundColor Yellow
}
else {
	Write-Host "`nScan complete. Modified $ModifiedCount file(s)." -ForegroundColor Green
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.