#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Shift + C to copy the current folder path to the clipboard
; File Explorer and Desktop are supported
; 50 ms pause included for reliability when copying from the File Explorer address bar
; Only active when File Explorer or the Desktop is the active window, so it doesn't override Ctrl + Shift + C in other apps

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

#If IsExplorerOrDesktop()

; Ctrl + Shift + C → Copy current folder path
^+c::
	; If the Desktop is the active window, copy the Desktop path directly
	if WinActive("ahk_class WorkerW") or WinActive("ahk_class Progman")
	{
		Clipboard := A_Desktop
		Return
	}
	Send ^l  ; focus address bar
	Sleep, 50  ; 50 ms pause to ensure File Explorer address bar path is copied reliably
	Send ^c  ; copy
Return
#If

; Returns true when File Explorer or the Desktop is the active window
IsExplorerOrDesktop()
{
	return WinActive("ahk_class CabinetWClass") or WinActive("ahk_class WorkerW") or WinActive("ahk_class Progman")
}

; End.