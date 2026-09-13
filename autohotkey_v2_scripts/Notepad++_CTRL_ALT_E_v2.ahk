#Requires AutoHotkey v2
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Alt + E to open any selected file(s) in Notepad++
; Files in File Explorer and on the Desktop are supported, and multiple files can be selected and opened simultaneously
; The script automatically detects whether the 64-bit or 32-bit version of Notepad++ is installed
; NOTE: If you want this to function in Remote Desktop sessions, make the following change in Remote Desktop:
;		Show Options button -> Local Resources tab -> Keyboard section -> Apply Windows key combinations -> On the remote computer

; Ctrl + Alt + E → Open selected file(s) in Notepad++ (auto-detects 64-bit or 32-bit installation)
^!e:: {
	local npp64 := "C:\Program Files\Notepad++\notepad++.exe"
	local npp32 := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	local npp := FileExist(npp64) ? npp64 : npp32
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
	local files := StrSplit(paths, "`n")
	local reversed := []
	loop files.Length
		reversed.Push(files[files.Length - A_Index + 1])
	local args := ""
	for file in reversed {
		file := Trim(file, " `t`r`n")  ; explicitly strip carriage returns and newlines
		if (file != "")
			args .= '"' file '" '
	}
	Run('"' npp '" ' Trim(args))
	A_Clipboard := ClipSaved
}

; End.