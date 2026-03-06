# Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/powershell_scripts
# This script sanitizes a file containing UNC (local) network file paths, each on a new line, down to just the filenames
# It is meant to be used in conjunction with File Explorer's "Copy Path" option:
# 1. Select file(s) in File Explorer -> Press CTRL-SHIFT-C -> Press CTRL-V into the appropriate application
# 2. Select file(s) in File Explorer -> Right-click one of the selected files -> Click "Copy as path" -> Press CTRL-V into the appropriate application
# 3. Select file(s) in File Explorer -> Click the three dots (...) -> Click the "Copy path" button -> Press CTRL-V into the appropriate application

# Example input line(s):
# "\\PATH\TO\FILENAME1"
# "//PATH/TO/FILENAME2"
# Output after processing:
# FILENAME1
# FILENAME2

# Each line is expected to:
# - Start and/or end with quotes
# - Have leading or trailing whitespace
# - Use either backslashes (\) or forward slashes (/)

# NOTE: Here's a one-line command that accomplishes everything this script does (aside from handling empty blank lines):
# Get-Content uncpaths.txt | ForEach-Object { ($_ -replace '^"|"$','').Trim() -replace '/','\' | Split-Path -Leaf }

# A slightly more robust one-line command that also skips empty lines:
# Get-Content paths.txt | ForEach-Object { ($_ -replace '^"|"$','').Trim() -replace '/','\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Split-Path -Leaf }
# These commands output the filenames to the pipeline, so they can be piped to Out-File, Set-Clipboard, etc.

# Prompt user for the file containing UNC/network file paths
$inputFile = Read-Host "Enter the full path to the file containing UNC/network paths"

# Check if the input file exists
if (-not (Test-Path $inputFile)) {
	Write-Host "`nError: Input file not found at '$inputFile'" -ForegroundColor Red
	exit 1
}

Write-Host "`nStripping UNC/network paths down to filenames...`n" -ForegroundColor Cyan

try {
	# Read all lines from the file
	$lines = Get-Content -Path $inputFile -ErrorAction Stop
	$processedLines = @()

	foreach ($line in $lines) {
		try {
			# Trim leading/trailing whitespace
			$trimmedLine = $line.Trim()

			# Remove surrounding quotes if present
			if ($trimmedLine.StartsWith('"') -and $trimmedLine.EndsWith('"')) {
				$trimmedLine = $trimmedLine.Substring(1, $trimmedLine.Length - 2)
			}

			# Normalize slashes (converts / to \)
			$trimmedLine = $trimmedLine -replace '/', '\'

			# Skip empty lines
			if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
				continue
			}

			# Extract the filename from the path
			$filename = [System.IO.Path]::GetFileName($trimmedLine)

			if ([string]::IsNullOrWhiteSpace($filename)) {
				throw "Could not extract filename from line: '$line'"
			}

			# Store for optional file write
			$processedLines += $filename

			# Output filename to console
			Write-Host $filename -ForegroundColor Green
		}
		catch {
			# Handle errors per line
			Write-Host "`nError processing line: $($_.Exception.Message)" -ForegroundColor Red
		}
	}

	Write-Host "`nFilename extraction complete!" -ForegroundColor Green

	# Ask user what to do with the processed list
	$overwriteOrNew = Read-Host "`nEnter 'Y' to overwrite the original file, 'N' to skip, or type a new file path to save results"

	if ($overwriteOrNew -match '^(?i)Y$') {
		try {
			# # Remove any empty or whitespace-only lines before saving
			$processedLines = $processedLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

			# # Join lines with `n, no trailing newline
			$finalContent = ($processedLines -join "`n")
			[System.IO.File]::WriteAllText($inputFile, $finalContent)

			Write-Host "`nProcessed filenames saved to '$inputFile'." -ForegroundColor Green
		}
		catch {
			Write-Host "`nError writing to file '$inputFile': $($_.Exception.Message)" -ForegroundColor Red
		}
	}
	elseif ($overwriteOrNew -match '^(?i)N$') {
		# Skip saving
		Write-Host "`nSkipping file save." -ForegroundColor Yellow
	}
	else {
		# User typed a new file path
		try {
			# Remove any accidental empty entries before saving
			$processedLines = $processedLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

			# Join lines with `n and save without trailing newline
			$finalContent = ($processedLines -join "`n")
			[System.IO.File]::WriteAllText($overwriteOrNew, $finalContent)

			Write-Host "`nProcessed filenames saved to '$overwriteOrNew'." -ForegroundColor Green
		}
		catch {
			Write-Host "`nError writing to file '$overwriteOrNew': $($_.Exception.Message)" -ForegroundColor Red
		}
	}
}
catch {
	Write-Host "`nError reading file: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}

# Read-Host # Uncomment when testing, prevents the script window from closing so you can review the output

# End.