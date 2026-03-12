; This script creates the shortcut CTRL + = (CTRL EQUAL) to duplicate the functionality of CTRL + NUMPAD+ on an extended keyboard
; This allows a Tenkeyless (TKL) keyboard to use the shortcut and requires AutoHotkey v2 (not compatible with v1)

#Requires AutoHotkey v2

#HotIf WinActive("ahk_class CabinetWClass")
^=:: {
	Send("{Blind}{NumpadAdd}")
}
return
#HotIf

; End.