#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; Creates the keyboard shortcut Ctrl + Alt + T to open PowerShell (Admin) in the current File Explorer folder or Desktop
; PowerShell 7 is used by default, falling back to PowerShell 5 if 7 is not installed
; NOTE: This script must run as administrator for the hotkey to open an elevated PowerShell window
; NOTE: If you want a non-admin PowerShell window instead, use the pwsh-user function (see master script for details)

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; Ctrl + Alt + T → Open PowerShell (Admin) in current folder or Desktop
^!t::
	; Check if the Desktop is the active/focused window first
	if WinActive("ahk_class WorkerW") or WinActive("ahk_class Progman")
	{
		currentFolder := A_Desktop
	}
	else
	{
		; Check for an open File Explorer window
		WinGet, id, ID, ahk_class CabinetWClass
		if !id
		{
			MsgBox, No File Explorer/Desktop window detected.
			Return
		}
		WinActivate, ahk_id %id%

		; Wait until the window is active instead of using a fixed Sleep
		WinWaitActive, ahk_id %id%, , 0.5  ; wait up to 0.5 seconds

		; Copy current folder from address bar
		ClipSaved := ClipboardAll
		Clipboard := ""
		Send ^l
		Sleep, 100  ; let Explorer register selection
		Send ^c
		ClipWait, 0.5
		currentFolder := Clipboard
		if !FileExist(currentFolder)
			currentFolder := A_Desktop  ; fallback
		Clipboard := ClipSaved
	}

	; Open PowerShell 7 as Administrator (falls back to PowerShell 5 if 7 is not installed)
	psExe := "C:\Program Files\PowerShell\7\pwsh.exe"
	if !FileExist(psExe)
		psExe := "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	Run, %psExe%, %currentFolder%, RunAs
Return

; End.