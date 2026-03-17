#Requires AutoHotkey v1.1
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; ==========================
; File Explorer AutoHotkey Hotkeys v1
; ==========================
; Hotkeys:
; Ctrl + =           Auto-resize Details View columns
; Ctrl + Shift + C   Copy current folder path (50 ms pause for reliability)
; Ctrl + Shift + X   Copy selected file path(s)
; Ctrl + Alt + T     Open PowerShell (Admin) in current folder or Desktop
; Ctrl + Alt + E     Open selected file(s) in Notepad++ (x86)
; Ctrl + Alt + V     Open selected file(s) in VSCode
; Ctrl + Shift + H   Show all hotkeys in a popup
; pwsh-user          Open non-admin PowerShell window from an Admin shell (defined in PowerShell profile)

; ==========================
; Run at Startup (Required for full functionality)
; ==========================
; The Ctrl + Alt + T hotkey requires this script to run as administrator.
; Using "Run as administrator" on a standard shortcut in shell:startup is
; silently ignored by Windows — the script will never load at boot.
; To run this script at startup with admin rights, use Task Scheduler instead:
;
; 1. Open Task Scheduler and click "Create Task" (NOT "Create Basic Task")
;
; 2. General tab:
;       Name: AutoHotKey Startup Script
;       Select "Run only when user is logged on"
;       Check "Run with highest privileges"
;       Configure for: Windows 10
;
; 3. Triggers tab:
;       Begin the task: At log on
;       Specific user: your username (or "Any user")
;       Ensure "Enabled" is checked
;
; 4. Actions tab:
;       Action: Start a program
;       Program/script: "C:\Program Files\AutoHotkey\AutoHotkeyU64.exe"
;       Add arguments: "\PATH\TO\File_Explorer_AutoHotkey_Hotkeys_v1.ahk"
;
; 5. Conditions tab:
;       Uncheck "Start the task only if the computer is on AC power"
;       Uncheck "Stop if the computer switches to battery power"
;
; 6. Settings tab (all defaults, listed for reference):
;       Check "Allow task to be run on demand"
;       "Stop the task if it runs longer than" set to 3 days
;       Check "If the running task does not end when requested, force it to stop"
;       "If the task is already running": Do not start a new instance
;
; 7. Click OK
;
; NOTE: If an "Open File - Security Warning" dialog appears on reboot,
;       uncheck "Always ask before opening this file" to prevent it recurring
;
; ALTERNATIVE: UIA Executable
; If you have AHK v2 installed AND installed v1 via "Install as additional version"
; in the v1 installer, UIA executables will be present in your v1 directory.
; In that case you can use the simpler UIA approach instead of Task Scheduler:
; 1. Create a shortcut in shell:startup
; 2. Set the shortcut Target to:
;      "C:\Program Files\AutoHotkey\v1.1.xx\AutoHotkeyU64_UIA.exe" "\PATH\TO\File_Explorer_AutoHotkey_Hotkeys_v1.ahk"
;      (replace xx with your installed v1 version number)
;      Use AutoHotkeyU64_UIA.exe for 64-bit systems (recommended) or AutoHotkeyU32_UIA.exe for 32-bit systems
;      (adjust the script path to match your actual location)
; 3. In shortcut Properties -> Advanced, enable "Run as administrator"
;
; NOTE: This approach is NOT available with a standalone v1 install — Task Scheduler
;       is required in that case

; ==========================
; Notes:
; ==========================
; - Runs in background, shows standard AHK tray icon with minimal menu
; - Ctrl + Alt + T (PowerShell Admin) will:
;       • Prompt for elevation if UAC is enabled
;       • Open non-admin if UAC is disabled
; - If you run File_Explorer_AutoHotkey_Hotkeys_v1.ahk using "Run as administrator," PowerShell will open as Admin
; - pwsh-user ensures you can still test scripts in a non-admin environment without closing elevated windows
; - Ctrl + Alt + E opens selected files in Notepad++ (x86 by default)
;   If you use the 64-bit version, update the path in the script accordingly
; - Ctrl + Alt + V opens selected files in VSCode (per-user install path by default)
;   If you have a system-wide install, update the path in the script accordingly

; ==========================
; PowerShell non-admin helper
; ==========================
; If you don't have a PowerShell profile, do the following:
; 1. Open PowerShell 5 AND PowerShell 7 and run: notepad $PROFILE
;    (click Yes if prompted to create a new file)
;    NOTE: If PowerShell says it cannot find the $PROFILE path, run this first:
;          New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force
; 2. Add this function to both profiles:
;       function pwsh-user {
;           # Opens a non-admin PowerShell window, even from an Admin session
;           # Matches the PowerShell version of the current session (5 or 7)
;           # NOTE: New window opens in the default directory, not the current one
;           $currentPwsh = Join-Path $PSHOME "pwsh.exe"
;           if (-not (Test-Path $currentPwsh)) {
;               $currentPwsh = Join-Path $PSHOME "powershell.exe"
;           }
;           explorer.exe $currentPwsh
;       }
; 3. Save and close both profiles
; 4. Reload each profile via: . $PROFILE (or close/re-open PowerShell) and now pwsh-user will work as intended


#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; ==========================
; Tray icon & menu
; ==========================
Menu, Tray, Tip, File Explorer AutoHotkey Hotkeys v1 (active)
Menu, Tray, NoStandard  ; removes default items like Suspend Hotkeys
Menu, Tray, Add, Show Hotkeys, ShowHotkeys
Menu, Tray, Add
Menu, Tray, Add, Exit, ExitScript  ; working exit menu item

; ==========================
; Hotkeys
; ==========================

; Ctrl + = → Auto-resize Details View columns
^=::
	Send {LCtrl down}{NumpadAdd}{LCtrl up}
Return

; Ctrl + Shift + C → Copy current folder path
^+c::
	Send ^l  ; focus address bar
	Sleep, 50  ; 50 ms pause to ensure File Explorer address bar path is copied reliably
	Send ^c  ; copy
Return

; Ctrl + Shift + X → Copy selected file path(s)
^+x::
	ClipSaved := ClipboardAll
	Clipboard := ""
	Send ^c
	ClipWait, 0.5
	If Clipboard =
	{
		Clipboard := ClipSaved
		MsgBox, No file selected in File Explorer/Desktop.
		Return
	}
	Clipboard := Clipboard  ; forces AHK to normalize Explorer clipboard file paths
Return

; Ctrl + Alt + T → Open PowerShell (Admin) in current folder or Desktop
; NOTE: If you want a non-admin PowerShell 5 or 7 window instead, use the pwsh-user function (documented above)
^!t::
	; Check if the Desktop is the active/focused window first
	if WinActive("ahk_class WorkerW") or WinActive("ahk_class Progman")
	{
		currentFolder := A_Desktop
	}
	else
	{
		; Check for an open File Explorer window
		WinGet, id, ID, ahk_class CabinetWClass
		if !id
		{
			MsgBox, No File Explorer/Desktop window detected.
			Return
		}
		WinActivate, ahk_id %id%

		; Wait until the window is active instead of using a fixed Sleep
		WinWaitActive, ahk_id %id%, , 0.5  ; wait up to 0.5 seconds

		; Copy current folder from address bar
		ClipSaved := ClipboardAll
		Clipboard := ""
		Send ^l
		Sleep, 100  ; let Explorer register selection
		Send ^c
		ClipWait, 0.5
		currentFolder := Clipboard
		if !FileExist(currentFolder)
			currentFolder := A_Desktop  ; fallback
		Clipboard := ClipSaved
	}

	; Open PowerShell 7 as Administrator (falls back to PowerShell 5 if 7 is not installed)
	psExe := "C:\Program Files\PowerShell\7\pwsh.exe"
	if !FileExist(psExe)
		psExe := "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	Run, %psExe%, %currentFolder%, RunAs
Return

; Ctrl + Alt + E → Open selected file(s) in Notepad++ (x86)
^!e::
	npp := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	ClipSaved := ClipboardAll
	Clipboard := ""
	Send ^c
	ClipWait, 0.5
	If Clipboard =
	{
		Clipboard := ClipSaved
		MsgBox, No file selected in File Explorer/Desktop.
		Return
	}
	; Build a single command with all file paths in correct tab order
	; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match
	; click order — Desktop selections tend to be most reliable for ordered multi-file selection
	files := StrSplit(Clipboard, "`n")
	reversed := []
	Loop, % files.Length()
		reversed.Push(files[files.Length() - A_Index + 1])
	args := ""
	For i, file in reversed
	{
		file := Trim(file, " `t`r`n")
		if (file != "")
			args .= """" file """ "
	}
	Run, %npp% %args%
	Clipboard := ClipSaved
Return

; Ctrl + Alt + V → Open selected file(s) in VSCode
^!v::
	; Uses 'code' via cmd.exe rather than Code.exe directly — handles multiple files and reuses existing window correctly
	; A_UserName dynamically resolves to the current Windows username at runtime (per-user install path)
	ClipSaved := ClipboardAll
	Clipboard := ""
	Send ^c
	ClipWait, 0.5
	If Clipboard =
	{
		Clipboard := ClipSaved
		MsgBox, No file selected in File Explorer/Desktop.
		Return
	}
	; Build a single command with all file paths in correct tab order
	; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match
	; click order — Desktop selections tend to be most reliable for ordered multi-file selection
	files := StrSplit(Clipboard, "`n")
	reversed := []
	Loop, % files.Length()
		reversed.Push(files[files.Length() - A_Index + 1])
	args := ""
	For i, file in reversed
	{
		file := Trim(file, " `t`r`n")
		if (file != "")
			args .= """" file """ "
	}
	; Run via cmd.exe using 'code' from PATH — correctly reuses existing VSCode window
	RunWait, %ComSpec% /c code %args%,, Hide
	Clipboard := ClipSaved
Return

; Ctrl + Shift + H → Show hotkeys popup
^+h::
	Gosub, ShowHotkeys
Return

; ==========================
; Show Hotkeys label for tray menu
; ==========================
ShowHotkeys:
MsgBox,
(
File Explorer Hotkeys v1

Ctrl + =`t`tAuto-resize Details View columns
Ctrl + Shift + C`tCopy current folder path
Ctrl + Shift + X`tCopy selected file path(s)
Ctrl + Alt + T`tOpen PowerShell (Admin) in current folder or Desktop
Ctrl + Alt + E`tOpen selected file(s) in Notepad++ (x86)
Ctrl + Alt + V`tOpen selected file(s) in VSCode
Ctrl + Shift + H`tShow all hotkeys in a popup

Tip:
Use "pwsh-user" in PowerShell to open a non-admin shell.
)
Return

; ==========================
; Exit label for tray menu
; ==========================
ExitScript:
	ExitApp
Return

; End.