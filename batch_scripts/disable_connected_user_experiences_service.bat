@echo off

@REM This script stops and disables the DiagTrack service (otherwise known as "Connected User Experiences and Telemetry") and must be run as Administrator, which requires creating a shortcut to the .bat file and enabling "Run as administrator" in Shortcut tab -> Advanced)
@REM In order for this script to run during startup, a "Run as administrator" shortcut to the .bat file must be put into C:\WINDOWS\System32\GroupPolicy\Machine\Scripts\Startup. This shortcut then needs to be put into gpedit.msc -> Computer Configuration -> Windows Settings -> Scripts (Startup/Shutdown) -> Startup

@REM NOTE: I've migrated this script to a more robust PowerShell version

@REM Stop the service
sc stop DiagTrack

@REM Disable the service startup type
sc config DiagTrack start=disabled

:end

@REM End.