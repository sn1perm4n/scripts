@echo off

@REM This script copies my Thunderbird profile from my PC to my NAS

robocopy C:\Users\USERNAME\AppData\Roaming\Thunderbird\Profiles\n4810uhh.default "\\NAS\Volume\Backups\Thunderbird\HOSTNAME" /E

@REM End.