@echo off

@REM This script disables the Remote Registry service. The commented lines only work in a domain environment.

@REM This commented section will remotely disable the Remote Registry service on another PC:
@REM sc \\HOSTNAME stop remoteregistry
@REM sc \\HOSTNAME config remoteregistry start=disabled

@REM Stop the service
sc stop remoteregistry

@REM Disable the service startup type
sc config remoteregistry start=disabled

@REM End.