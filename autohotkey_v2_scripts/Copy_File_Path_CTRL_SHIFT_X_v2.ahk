#Requires AutoHotkey v2
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Shift + X to copy the full path(s) of selected file(s) to the clipboard
; File Explorer and Desktop are supported
; Only active when File Explorer or the Desktop is the active window, so it doesn't override Ctrl + Shift + X in other apps

#HotIf IsExplorerOrDesktop()

; Ctrl + Shift + X → Copy selected file path(s)
^+x:: {
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
	; Clean up paths (trim each line)
	local files := StrSplit(paths, "`n")
	local joined := ""
	for file in files {
		local t := Trim(file)
		if (t != "")
			joined .= t "`n"
	}
	joined := RTrim(joined, "`n")
	A_Clipboard := joined
}
#HotIf

; Returns true when File Explorer or the Desktop is the active window
IsExplorerOrDesktop() {
	return WinActive("ahk_class CabinetWClass") || WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman")
}

; End.