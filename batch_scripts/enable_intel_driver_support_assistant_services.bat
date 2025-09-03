@echo off

@REM This script enables the "Intel Driver and Support Assistant" services (must be run as Administrator, which requires creating a shortcut to the .bat file and enabling "Run as administrator" in Shorcut tab -> Advanced)

@REM NOTE: I've migrated this script to a more robust PowerShell version

@REM Start the service
sc start DSAService

@REM Set the service startup type to Manual
sc config DSAService start=demand

@REM Start the service
sc start DSAUpdateService

@REM Set the service startup type to Manual
sc config DSAUpdateService start=demand

:end

@REM End.