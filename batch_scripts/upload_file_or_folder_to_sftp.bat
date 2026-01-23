@echo off

REM This script uploads a file (or optionally a folder) to SFTP via WinSCP from a directory.

"C:\Program Files (x86)\WinSCP\WinSCP.com" ^
  /log="\\PATH\TO\LOCAL\DIRECTORY\WinSCP.log" /ini=nul ^ REM WinSCP.log location (recommend using the same directory the file/folder is uploaded from)
  /command ^
    "open sftp://USERNAME:INSERT_PASSWORD_HERE@HOSTNAME/ -hostkey=""INSERT_SSH_HOSTKEY_HERE"" -rawsettings Cipher=""INSERT_CIPHER_HERE"" KEX=""INSERT_KEX_HERE""" ^
    "cd /PATH/TO/REMOTE/DIRECTORY/HERE" ^ REM Remote destination directory (i.e. /mnt/ebs/home/USERNAME)
    "lcd \\PATH\TO\LOCAL\DIRECTORY" ^ REM Can be a Network Share (i.e. \\PATH\TO\FOLDER) or a local directory (i.e. C:\Users\USERNAME\Folder)
    "put FILENAME.EXTENSION" ^ REM To upload a folder instead, use: put -r FOLDER_NAME (instead of put FILENAME.EXTENSION)
    "exit"

set WINSCP_RESULT=%ERRORLEVEL%
if %WINSCP_RESULT% equ 0 (
  echo Success
) else (
  echo Error
)

exit /b %WINSCP_RESULT%

REM End.