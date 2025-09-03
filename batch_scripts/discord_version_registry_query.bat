@echo off

REM Queries the Discord version number in the Windows Registry. Discord fails to update its version number when the program updates, which causes programs such as WinGet to report the out-of-date version

@REM NOTE: I've migrated this script to a more robust PowerShell version

reg query HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord -v DisplayVersion

cmd /k

:end

REM End.