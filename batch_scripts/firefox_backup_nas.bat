@echo off

@REM This script copies my Firefox profile from my PC to my NAS

robocopy C:\Users\USERNAME\AppData\Roaming\Mozilla\Firefox\Profiles\b1kqjfg2.default "\\NAS\Volume\Backups\Firefox\HOSTNAME" /E

@REM End.