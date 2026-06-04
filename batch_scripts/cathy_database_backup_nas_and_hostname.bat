@echo off

@REM This script copies my Cathy databases and .bak files to my NAS and another computer on my network (SFTP functionality and placeholder password commented out)

xcopy "C:\Program Files (x86)\Cathy 2.33\-Media-1.caf" "\\NAS\Volume\Backups\Cathy_HDD_Catalogs" /k /o /y
xcopy "C:\Program Files (x86)\Cathy 2.33\-Media-1.bak" "\\NAS\Volume\Backups\Cathy_HDD_Catalogs" /k /o /y
xcopy "C:\Program Files (x86)\Cathy 2.33\-Volume-1.caf" "\\NAS\Volume\Backups\Cathy_HDD_Catalogs" /k /o /y
xcopy "C:\Program Files (x86)\Cathy 2.33\-Volume-1.caf.bak" "\\NAS\Volume\Backups\Cathy_HDD_Catalogs" /k /o /y

@REM A quick ping test to see if the remote computer is online (aborts copy operation if it isn't)
ping -n 1 HOSTNAME
if %errorlevel% neq 0 (
    echo HOSTNAME Offline
    goto end
    )
	
@REM If ping test succeeds, copy the files	
xcopy "C:\Program Files (x86)\Cathy 2.33\-Media-1.caf" "\\HOSTNAME\c$\Program Files (x86)\Cathy 2.33" /k /o /y
xcopy "C:\Program Files (x86)\Cathy 2.33\-Media-1.caf.bak" "\\HOSTNAME\c$\Program Files (x86)\Cathy 2.33" /k /o /y
xcopy "C:\Program Files (x86)\Cathy 2.33\-Volume-1.caf" "\\HOSTNAME\c$\Program Files (x86)\Cathy 2.33" /k /o /y
xcopy "C:\Program Files (x86)\Cathy 2.33\-Volume-1.caf.bak" "\\HOSTNAME\c$\Program Files (x86)\Cathy 2.33" /k /o /y


@REM This section is commented out because I realized I don't want my Cathy database on an SFTP server other people have access to, but the code is useful so I wanted to keep it
@REM set localdir="C:\Program Files (x86)\Cathy 2.33"

@REM "C:\Program Files (x86)\WinSCP\WinSCP.com" ^
@REM   /log="\\NAS\Volume\Backups\Cathy_HDD_Catalogs\WinSCP.log" /ini=nul ^
@REM   /command ^
@REM     "open sftp://USERNAME:PASSWORD@DOMAIN.NET/ -hostkey=""ssh-ed25519 256 44:29:e2:b6:ff:45:55:a8:f9:15:36:4a:40:8b:1a:86"" -rawsettings Cipher=""aes,blowfish,3des,chacha20,WARN,arcfour,des"" KEX=""ecdh,dh-gex-sha1,dh-group14-sha1,dh-group1-sha1,rsa,WARN""" ^
@REM     "cd /mnt/ebs/home/USERNAME/Backups/Cathy_HDD_Catalogs" ^
@REM     "lcd "%localdir%"" ^
@REM     "put -Media-1.caf" ^
@REM     "put -Media-1.caf.bak" ^
@REM     "put -Volume-1.caf" ^
@REM     "put -Volume-1.caf.bak" ^
@REM     "exit"

@REM set WINSCP_RESULT=%ERRORLEVEL%
@REM if %WINSCP_RESULT% equ 0 (
@REM   echo Success
@REM ) else (
@REM   echo Error
@REM )

@REM exit /b %WINSCP_RESULT%

:end

@REM End.