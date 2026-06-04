; This AutoHotkey v1 script creates the keyboard shortcut CTRL + ALT + E to open any selected file in Notepad++ (if you want to change the shortcut modify line 3). Files in File Explorer and the Desktop are supported (the Desktop portion requires extra logic), and numerous files can be selected and opened at the same time as well. If you run the 64-bit version of Notepad++ you'll need to comment (or delete) line 5 and uncomment line 6. Lastly, if you want this to function in Remote Desktop sessions, you'll need to make the following change in Remote Desktop: Show Options button -> Local Resources tab -> Keyboard section -> Apply Windows key combinations -> On the remote computer

^!e::  ; Ctrl + Alt + E
{
	npp := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	; npp := "C:\Program Files\Notepad++\notepad++.exe"

	; ==============================
	; Try to handle File Explorer selections via Ctrl+C
	; ==============================
	; Save current clipboard
	ClipSaved := ClipboardAll
	Clipboard := ""  ; Clear clipboard

	; Send Ctrl+C to copy selected files/folders
	Send, ^c
	ClipWait, 0.5  ; Wait up to 0.5 sec for clipboard to populate

	if (Clipboard = "")
	{
		; Restore previous clipboard
		Clipboard := ClipSaved
		MsgBox, 48, Error, No file selected in Explorer/Desktop.
		return
	}

	; Loop through each line in clipboard (supports multi-select)
	Loop, Parse, Clipboard, `n, `r
	{
		Run, "%npp%" "%A_LoopField%"
	}

	; Restore previous clipboard
	Clipboard := ClipSaved
	return
}

; End.