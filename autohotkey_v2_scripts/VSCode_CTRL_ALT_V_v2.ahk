#Requires AutoHotkey v2
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Alt + V to open selected file(s) in VSCode
; File Explorer and Desktop are supported, and multiple files can be selected and opened simultaneously
; Uses 'code' via cmd.exe to handle multiple files and reuse the existing VSCode window correctly
; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match click order
;	Desktop selections tend to be most reliable for ordered multi-file selection

; Ctrl + Alt + V → Open selected file(s) in VSCode
^!v:: {
	; Uses 'code' via cmd.exe rather than Code.exe directly — handles multiple files and reuses existing window correctly
	; A_UserName dynamically resolves to the current Windows username at runtime (per-user install path)
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
	; Build a single command with all file paths in correct tab order
	; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match
	; click order — Desktop selections tend to be most reliable for ordered multi-file selection
	local files := StrSplit(paths, "`n")
	local reversed := []
	loop files.Length
		reversed.Push(files[files.Length - A_Index + 1])
	local args := ""
	for file in reversed {
		file := Trim(file)
		if (file != "")
			args .= '"' file '" '
	}
	; Run via cmd.exe using 'code' from PATH — correctly reuses existing VSCode window
	RunWait(A_ComSpec ' /c code ' Trim(args),, "Hide")
	A_Clipboard := ClipSaved
}

; End.