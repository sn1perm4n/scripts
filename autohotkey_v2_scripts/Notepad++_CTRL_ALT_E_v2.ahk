; This AutoHotkey v2 script creates the keyboard shortcut CTRL + ALT + E to open any selected file in Notepad++ (if you want to change the shortcut modify line 3). Files in File Explorer and the Desktop are supported (the Desktop portion requires extra logic), and numerous files can be selected and opened at the same time as well. If you run the 64-bit version of Notepad++ you'll need to comment (or delete) line 5 and uncomment line 6. Lastly, if you want this to function in Remote Desktop sessions, you'll need to make the following change in Remote Desktop: Show Options button -> Local Resources tab -> Keyboard section -> Apply Windows key combinations -> On the remote computer

^!e::  ; Ctrl + Alt + E
{
	npp := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	; npp := "C:\Program Files\Notepad++\notepad++.exe"

	; ==============================
	; Try to handle File Explorer selections via Ctrl+C
	; ==============================
	; Save current clipboard
	ClipSaved := ClipboardAll()
	A_Clipboard := ""  ; Clear clipboard

	; Send Ctrl+C to copy selected files/folders
	Send("^c")
	ClipWait(0.5)  ; Wait up to 0.5 sec for clipboard to populate

	if (A_Clipboard = "")
	{
		; Restore previous clipboard
		A_Clipboard := ClipSaved
		MsgBox("No file selected in Explorer/Desktop.", "Error", "Iconx")
		return
	}

	; Loop through each line in clipboard (supports multi-select)
	for line in StrSplit(A_Clipboard, "`n", "`r")
	{
		Run(npp ' "' line '"')
	}

	; Restore previous clipboard
	A_Clipboard := ClipSaved
}

; End.