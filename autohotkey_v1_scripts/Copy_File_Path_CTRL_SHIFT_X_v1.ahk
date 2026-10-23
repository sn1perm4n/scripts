#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Shift + X to copy the full path(s) of selected file(s) to the clipboard
; File Explorer and Desktop are supported
; Only active when File Explorer or the Desktop is the active window, so it doesn't override Ctrl + Shift + X in other apps

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

#If IsExplorerOrDesktop()

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
#If

; Returns true when File Explorer or the Desktop is the active window
IsExplorerOrDesktop()
{
	return WinActive("ahk_class CabinetWClass") or WinActive("ahk_class WorkerW") or WinActive("ahk_class Progman")
}

; End.