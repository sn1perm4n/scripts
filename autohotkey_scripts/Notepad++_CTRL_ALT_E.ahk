; This AutoHotkey v1 script creates the keyboard shortcut CTRL + ALT + E to open any selected file in Notepad++ (if you want to change the shortcut modify line 3). Files in File Explorer and the Desktop are supported (the Desktop portion requires extra logic), and numerous files can be selected and opened at the same time as well. If you run the 64-bit version of Notepad++ you'll need to comment (or delete) line 5 and uncomment line 6.

^!e::  ; Ctrl + Alt + E
{
	npp := "C:\Program Files (x86)\Notepad++\notepad++.exe" ; 32-bit version
	; npp := "C:\Program Files\Notepad++\notepad++.exe" ; 64-bit version
	WinGetClass, winClass, A

	; ==============================
	; FILE EXPLORER LOGIC
	; ==============================
	if (winClass = "CabinetWClass" || winClass = "ExplorerWClass")
	{
		shell := ComObjCreate("Shell.Application")
		WinGet, hwnd, ID, A
		found := false

		for window in shell.Windows
		{
			if (window.HWND = hwnd)
			{
				sel := window.Document.SelectedItems
				if (sel.Count = 0)
				{
					MsgBox, 48, Error, No file selected in File Explorer.
					return
				}

				for item in sel
					Run, % """" npp """ """ item.Path """"

				found := true
				break
			}
		}

		if (!found)
			MsgBox, 48, Error, Active Explorer window not detected.

		return
	}

	; ==============================
	; DESKTOP LOGIC
	; ==============================
	hwnd := WinExist("ahk_class Progman")
	if !hwnd
	{
		WinGet, hwndList, List, ahk_class WorkerW
		hwnd := hwndList1
	}

	ControlGet, List, List, Selected Col1, SysListView321, ahk_id %hwnd%

	if (List = "")
	{
		MsgBox, 48, Error, No file selected on the Desktop.
		return
	}

	Loop, Parse, List, `n
		Run, "%npp%" "%A_Desktop%\%A_LoopField%"
}
return

; End.