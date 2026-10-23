#Requires AutoHotkey v2
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Shift + Z to copy the filename(s) of selected file(s) to the clipboard without the full path
; File Explorer and Desktop are supported, and multiple files can be selected simultaneously
; Filenames are sorted alphabetically (case-insensitive)
; Only active when File Explorer or the Desktop is the active window, so it doesn't override Ctrl + Shift + Z (Redo) in other apps

#HotIf IsExplorerOrDesktop()

; Ctrl + Shift + Z → Copy selected filename(s) only (no path)
^+z:: {
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^c")
	if (!ClipWait(2)) {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	local paths := A_Clipboard
	if (paths = "") {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	local files := StrSplit(paths, "`n")
	local joined := ""
	for file in files {
		file := Trim(file, " `t`r`n")
		if (file != "") {
			SplitPath(file, &filename)
			joined .= filename "`n"
		}
	}
	joined := RTrim(joined, "`n")
	; Sort filenames case-insensitively (default Sort behavior)
	joined := Sort(joined)
	A_Clipboard := joined
}
#HotIf

; Returns true when File Explorer or the Desktop is the active window
IsExplorerOrDesktop() {
	return WinActive("ahk_class CabinetWClass") || WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman")
}

; End.