#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Alt + E to open any selected file(s) in Notepad++
; Files in File Explorer and on the Desktop are supported, and multiple files can be selected and opened simultaneously
; The script automatically detects whether the 64-bit or 32-bit version of Notepad++ is installed
; NOTE: If you want this to function in Remote Desktop sessions, make the following change in Remote Desktop:
;		Show Options button -> Local Resources tab -> Keyboard section -> Apply Windows key combinations -> On the remote computer

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; Ctrl + Alt + E → Open selected file(s) in Notepad++ (auto-detects 64-bit or 32-bit installation)
^!e::
	npp64 := "C:\Program Files\Notepad++\notepad++.exe"
	npp32 := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	npp := FileExist(npp64) ? npp64 : npp32
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
	; Build a single command with all file paths in correct tab order
	; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match
	; click order — Desktop selections tend to be most reliable for ordered multi-file selection
	files := StrSplit(Clipboard, "`n")
	reversed := []
	Loop, % files.Length()
		reversed.Push(files[files.Length() - A_Index + 1])
	args := ""
	For i, file in reversed
	{
		file := Trim(file, " `t`r`n")
		if (file != "")
			args .= """" file """ "
	}
	Run, %npp% %args%
	Clipboard := ClipSaved
Return

; End.