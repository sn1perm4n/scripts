#Requires AutoHotkey v2
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates the keyboard shortcut Ctrl + = (Ctrl Equal) to duplicate the functionality of Ctrl + Numpad+ on an extended keyboard
; This allows any keyboard that lacks a number pad (i.e. Tenkeyless (TKL), laptop, etc.) to use the Auto-Resize Details View File Explorer shortcut
; Only active when File Explorer is the focused window

#HotIf WinActive("ahk_class CabinetWClass")
^=:: {
	Send("{LCtrl down}{NumpadAdd}{LCtrl up}")
}
#HotIf

; End.