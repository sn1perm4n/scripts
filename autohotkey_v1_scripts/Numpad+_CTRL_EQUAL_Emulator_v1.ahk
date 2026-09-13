#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; This script creates the keyboard shortcut Ctrl + = (Ctrl Equal) to duplicate the functionality of Ctrl + Numpad+ on an extended keyboard
; This allows any keyboard that lacks a number pad (i.e. Tenkeyless (TKL), laptop, etc.) to use the Auto-Resize Details View File Explorer shortcut

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

#If WinActive("ahk_class CabinetWClass")
^=::
	Send {Blind}{NumpadAdd}
Return
#If

; End.