#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Shift + C to copy the current folder path to the clipboard
; File Explorer and Desktop are supported
; 50 ms pause included for reliability when copying from the File Explorer address bar

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

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

; End.