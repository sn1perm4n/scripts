# This script checks a directory of scripts for space indentation and replaces them with tabs (it can also check an individual script as well, just modify $scriptFileOrDirectory accordingly).

# Path to the directory containing scripts (can also be pointed at an individual script)
$scriptFileOrDirectory = "INSERT_PATH_TO_YOU_SCRIPT_HERE" # i.e. C:\Scripts\test.ps1, C:\Scripts, \\REMOTE\SHARE, etc."

# Number of spaces per tab
$spacesPerTab = 4

# Get all .ps1 files recursively
Get-ChildItem -Path $scriptFileOrDirectory -Filter *.ps1 -Recurse | ForEach-Object {
	$file = $_.FullName
	Write-Host "Processing $file" -ForegroundColor Cyan

	$changed = $false
	$newContent = Get-Content $file | ForEach-Object {
		$line = $_
		if ($line -match '^( +)') {
			$spaces = $matches[1].Length
			$tabCount = [math]::Floor($spaces / $spacesPerTab)
			$remainingSpaces = $spaces % $spacesPerTab

			# Construct new leading whitespace using tabs + leftover spaces
			$newIndent = ("`t" * $tabCount) + (" " * $remainingSpaces)
			$line = $newIndent + $line.Substring($spaces)

			Write-Host "  Replaced $spaces spaces with $tabCount tabs (+$remainingSpaces spaces) on line ${lineNumber}" -ForegroundColor Yellow
			$changed = $true
		}
		$line
	}

	if ($changed) {
		# Backup original file
		Copy-Item $file "$file.bak" -Force
		# Save modified content
		Set-Content $file $newContent # Comment this line if you want to preview any changes
		Write-Host "Updated $file (backup saved as $file.bak)." -ForegroundColor Green
	} else {
		Write-Host "No changes needed."
	}
}
