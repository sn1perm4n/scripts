#Requires AutoHotkey v2
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Shift + C to copy the current folder path to the clipboard
; File Explorer and Desktop are supported
; Desktop path is copied directly via A_Desktop when the Desktop is the active window

; Ctrl + Shift + C → Copy current folder path
^+c:: {
	; If the Desktop is the active window, copy the Desktop path directly
	if WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman") {
		A_Clipboard := A_Desktop
		return
	}
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^l")
	Sleep(100)
	Send("^a")
	Sleep(50)
	Send("^c")
	ClipWait(2)
	local path := A_Clipboard
	Send("{Escape}")
	if (path = "") {
		A_Clipboard := ClipSaved
		MsgBox("Failed to copy folder path.")
	} else {
		A_Clipboard := path
	}
}

; End.