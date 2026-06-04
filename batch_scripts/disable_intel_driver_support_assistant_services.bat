@echo off

@REM This script disables the "Intel Driver and Support Assistant" services (must be run as Administrator, which requires creating a shortcut to the .bat file and enabling "Run as administrator" in Shorcut tab -> Advanced)

@REM NOTE: I've migrated this script to a more robust PowerShell version

@REM Stop the service
sc stop DSAService

@REM Disable the service startup type
sc config DSAService start=disabled

@REM Stop the service
sc stop DSAUpdateService

@REM Disable the service startup type
sc config DSAUpdateService start=disabled

:end

@REM End.