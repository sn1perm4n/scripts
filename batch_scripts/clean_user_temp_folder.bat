@echo off

@REM This script deletes and re-creates the temp folder, can configure to run during logon.

rd /s /q %temp%
mkdir %temp%

@REM End.