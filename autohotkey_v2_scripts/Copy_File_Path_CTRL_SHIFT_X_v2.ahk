#Requires AutoHotkey v2
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Shift + X to copy the full path(s) of selected file(s) to the clipboard
; File Explorer and Desktop are supported

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

; End.