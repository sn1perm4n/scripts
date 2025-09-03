@echo off

@REM This script updates the winget source database and then runs the upgrade command so potential updates can be seen (must be run as Administrator)
@REM Individual packages can be upgraded via their ID, i.e.: "winget upgrade Microsoft.VCRedist.2013.x86"
@REM If you want to upgrade everything, you can run "winget upgrade --all"
@REM Available commands: https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade
@REM winget pin add --id <APP_ID> - Disables version checking for said app (useful to prevent an app from updating)

@REM Update source database
winget source update

@REM Show programs that need updating
winget upgrade

@REM Keep the Command Prompt running so user can input a command
cmd /k

:end

@REM End.