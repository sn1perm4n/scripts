; ==========================
; File Explorer AutoHotkey Hotkeys v1
; ==========================
; Runs in background, shows standard AHK tray icon with minimal menu

; Hotkeys:
; Ctrl + =           Auto-resize Details View columns
; Ctrl + Shift + C   Copy current folder path (50 ms pause for reliability)
; Ctrl + Shift + X   Copy selected file path(s)
; Ctrl + Alt + T     Open PowerShell 7 (Admin) in current folder
; Ctrl + Alt + E     Open selected file(s) in Notepad++
; pwsh-user          Open non-admin PowerShell 7 from an Admin shell (defined in PowerShell profile)

; Notes:
; - Ctrl + Alt + T (PowerShell Admin) will:
;       • Prompt for elevation if UAC is enabled
;       • Open non-admin if UAC is disabled
; - If you run File_Explorer_AutoHotkey_Hotkeys_v1.ahk using "Run as administrator," PowerShell will open as Admin
; - pwsh-user ensures you can still test scripts in a non-admin environment without closing elevated windows
; - Ctrl + Alt + E opens selected files in Notepad++ (x86 by default)  
;   If you use the 64-bit version, update the path in the script accordingly

; ==========================
; PowerShell non-admin helper
; ==========================
; If you don't have a PowerShell profile, do the following:
; 1. Open PowerShell and type: notepad $PROFILE
; 2. Add this function:
;       function pwsh-user {
;           ; Opens a non-admin PowerShell 7 window, even from an Admin session
;           explorer.exe "C:\Program Files\PowerShell\7\pwsh.exe"
;       }
; 3. Save and close the profile
; 4. Reload the profile via: . $PROFILE and now pwsh-user will work as intended


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
		MsgBox, No file selected in Explorer/Desktop.
		Return
	}
	Clipboard := Clipboard  ; forces AHK to normalize Explorer clipboard file paths
Return

; Ctrl + Alt + T → Open PowerShell 7 (Admin) in current folder
; Note: If you want a non-admin PowerShell 7 window instead, use the pwsh-user function (documented above)
^!t::
	; Activate the last active Explorer window
	WinGet, id, ID, ahk_class CabinetWClass
	if !id
	{
		MsgBox, No Explorer window detected.
		Return
	}
	WinActivate, ahk_id %id%

	; Wait until the window is active instead of using a fixed Sleep
	WinWaitActive, ahk_id %id%, , 0.5  ; wait up to 0.5 seconds
;	Sleep, 100  ; let window become active

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

	; Open PowerShell 7 as Administrator
	psExe := "C:\Program Files\PowerShell\7\pwsh.exe"
	Run, %psExe%, %currentFolder%, RunAs
Return

; Ctrl + Alt + E → Open selected file(s) in Notepad++ (32-bit)
^!e::
	npp := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	ClipSaved := ClipboardAll
	Clipboard := ""
	Send ^c
	ClipWait, 0.5
	If Clipboard =
	{
		Clipboard := ClipSaved
		MsgBox, No file selected in Explorer/Desktop.
		Return
	}
	Loop, Parse, Clipboard, `n, `r
	{
		Run, %npp% "%A_LoopField%"
	}
	Clipboard := ClipSaved
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
Ctrl + Alt + T`tOpen PowerShell 7 (Admin) in current folder
Ctrl + Alt + E`tOpen selected file(s) in Notepad++

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