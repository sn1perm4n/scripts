@echo off

@REM Uses WMIC to query Installed Programs and displays Name, Version, and Vendor. Displays the best in regular Notepad (i.e. don't use Notepad++)

WMIC product get name, vendor, version > C:\Users\USERNAME\Desktop\Installed_Programs_List.txt

@REM End.