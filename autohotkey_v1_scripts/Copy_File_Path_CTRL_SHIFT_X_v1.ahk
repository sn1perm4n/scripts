#Requires AutoHotkey v1.1
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Shift + X to copy the full path(s) of selected file(s) to the clipboard
; File Explorer and Desktop are supported

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

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

; End.