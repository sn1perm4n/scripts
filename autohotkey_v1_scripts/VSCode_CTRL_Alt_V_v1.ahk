#Requires AutoHotkey v1.1
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Alt + V to open selected file(s) in VSCode
; File Explorer and Desktop are supported, and multiple files can be selected and opened simultaneously
; Uses 'code' via cmd.exe to handle multiple files and reuse the existing VSCode window correctly
; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match click order
;	Desktop selections tend to be most reliable for ordered multi-file selection

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; Ctrl + Alt + V → Open selected file(s) in VSCode
^!v::
	; Uses 'code' via cmd.exe rather than Code.exe directly — handles multiple files and reuses existing window correctly
	; A_UserName dynamically resolves to the current Windows username at runtime (per-user install path)
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
	; Run via cmd.exe using 'code' from PATH — correctly reuses existing VSCode window
	RunWait, %ComSpec% /c code %args%,, Hide
	Clipboard := ClipSaved
Return

; End.