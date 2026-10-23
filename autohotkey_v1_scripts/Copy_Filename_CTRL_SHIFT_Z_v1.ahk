#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Shift + Z to copy the filename(s) of selected file(s) to the clipboard without the full path
; File Explorer and Desktop are supported, and multiple files can be selected simultaneously
; Filenames are sorted alphabetically (case-insensitive)
; Only active when File Explorer or the Desktop is the active window, so it doesn't override Ctrl + Shift + Z (Redo) in other apps

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

#If IsExplorerOrDesktop()

; Ctrl + Shift + Z → Copy selected filename(s) only (no path)
^+z::
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
	files := StrSplit(Clipboard, "`n")
	joined := ""
	For i, file in files
	{
		file := Trim(file, " `t`r`n")
		if (file != "")
		{
			SplitPath, file, filename
			joined .= filename "`n"
		}
	}
	joined := RTrim(joined, "`n")
	; Sort filenames case-insensitively (default Sort behavior)
	Sort, joined
	Clipboard := joined
Return
#If

; Returns true when File Explorer or the Desktop is the active window
IsExplorerOrDesktop()
{
	return WinActive("ahk_class CabinetWClass") or WinActive("ahk_class WorkerW") or WinActive("ahk_class Progman")
}

; End.