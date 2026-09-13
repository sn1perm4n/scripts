#Requires AutoHotkey v2
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + Alt + T to open PowerShell (Admin) in the current File Explorer folder or Desktop
; PowerShell 7 is used by default, falling back to PowerShell 5 if 7 is not installed
; NOTE: This script must run as administrator for the hotkey to open an elevated PowerShell window
; NOTE2: If you want a non-admin PowerShell window instead, use the pwsh-user function (see master script for details)

; Ctrl + Alt + T → Open PowerShell (Admin) in current folder or Desktop
^!t:: {
	local currentFolder := ""

	; Check if the Desktop is the active/focused window first
	if WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman") {
		currentFolder := A_Desktop
	} else {
		; Check for an open File Explorer window
		hwndExplorer := WinExist("ahk_class CabinetWClass")
		if hwndExplorer {
			WinActivate("ahk_id " hwndExplorer)
			WinWaitActive("ahk_id " hwndExplorer,, 1)
			local ClipSaved := ClipboardAll()
			A_Clipboard := ""
			Send("^l")
			Sleep(100)
			Send("^a")
			Sleep(50)
			Send("^c")
			ClipWait(2)
			currentFolder := A_Clipboard
			Send("{Escape}")
			if (!FileExist(currentFolder))
				currentFolder := A_Desktop
			A_Clipboard := ClipSaved
		} else {
			MsgBox("No File Explorer/Desktop window detected.")
			Return
		}
	}

	; Open PowerShell as Administrator (falls back to PowerShell 5 if 7 is not installed)
	local psExe := "C:\Program Files\PowerShell\7\pwsh.exe"
	if (!FileExist(psExe))
		psExe := "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	Run(psExe " -NoExit -Command Set-Location '" currentFolder "'",, "RunAs")
}

; End.