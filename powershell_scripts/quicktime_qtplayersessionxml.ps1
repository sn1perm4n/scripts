# This script looks for QTPlayerSession.xml and if it exists, it gets replaced with an optimized config from a network location. If QTPlayerSession.xml isn't found the script exits.

$local = "C:\Users\$env:UserName\AppData\Local\Apple Computer\QuickTime\QTPlayerSession.xml"
$remote = "\\x.x.x.x\Logon\quicktime_script\QTPlayerSession.xml"
$pathLocal = "C:\Users\$env:UserName\AppData\Local\Apple Computer\QuickTime\QTPlayerSession.xml"
$fileExists = Test-Path $local

# Checks for and replaces QTPlayerSession.xml if it exists
if ($fileExists -eq $True)
{
	Copy-Item -Force -Path $remote -Destination $pathLocal
}

# If QTPlayerSession.xml doesn't exist, exit
else
{
	Exit
}

Write-Host "Successfully replaced 'QTPlayerSession.xml' if the file existed."

# End.