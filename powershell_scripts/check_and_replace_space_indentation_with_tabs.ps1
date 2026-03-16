# This script checks a folder of PowerShell scripts or an individual PowerShell script for space indentation and replaces with tab indentation

# Number of spaces per tab
# Converts leading spaces to tabs (preserves leftover spaces beyond full tabs)
$spacesPerTab = 4

# Prompt the user for a directory or individual script file
$scriptFileOrDirectory = Read-Host "Enter the path to a PowerShell script directory or a single .ps1 file"

# Validate the path
if (-not (Test-Path $scriptFileOrDirectory)) {
	Write-Host "`nThe path '$scriptFileOrDirectory' does not exist. Exiting..." -ForegroundColor Red
	exit
}

# Determine if path is a directory or a single file
if ((Get-Item $scriptFileOrDirectory).PSIsContainer) {
	# Directory: get all .ps1 files recursively
	$files = Get-ChildItem -Path $scriptFileOrDirectory -Filter *.ps1 -Recurse
	if ($files.Count -eq 0) {
		Write-Host "`nNo .ps1 files found in the directory. Exiting..." -ForegroundColor Yellow
		exit
	}
} else {
	# Single file: check extension
	if ($scriptFileOrDirectory -notlike "*.ps1") {
		Write-Host "`nThe file '$scriptFileOrDirectory' is not a .ps1 script. Exiting..." -ForegroundColor Red
		exit
	}
	$files = @(Get-Item $scriptFileOrDirectory) # wrap in array for consistency
}

# Process each file
foreach ($fileObj in $files) {
	$file = $fileObj.FullName
	Write-Host "`nProcessing $file" -ForegroundColor Cyan

	$changed = $false
	$newContent = @()
	$lineNumber = 0

	foreach ($line in Get-Content $file) {
		$lineNumber++

		# Match any leading whitespace (spaces or tabs)
		if ($line -match '^([ \t]+)') {
			$leading = $matches[1]

			# Count total spaces: treat tabs as $spacesPerTab spaces
			$spaceCount = ($leading -replace "`t", (" " * $spacesPerTab)).Length

			$tabCount = [math]::Floor($spaceCount / $spacesPerTab)
			$remainingSpaces = $spaceCount % $spacesPerTab

			# Build new leading whitespace (tabs + leftover spaces)
			$newIndent = ("`t" * $tabCount) + (" " * $remainingSpaces)
			$newLine = $newIndent + $line.Substring($leading.Length)

			# Only mark as changed if the line actually differs
			if ($newLine -ne $line) {
				$line = $newLine
				Write-Host "  Replaced leading whitespace with $tabCount tabs + $remainingSpaces spaces on line $lineNumber" -ForegroundColor Yellow
				$changed = $true
			}
		}

		$newContent += $line
	}

	if ($changed) {
		# Backup original file
		Copy-Item $file "$file.bak" -Force
		# Save modified content
		Set-Content $file $newContent # Comment this line if you want to preview any changes
		Write-Host "`nUpdated $file (backup saved as $file.bak)." -ForegroundColor Green
	} else {
		Write-Host "`nNo changes needed." -ForegroundColor Green
	}
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.