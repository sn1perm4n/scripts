; This script creates the shortcut CTRL + = (CTRL EQUAL) to duplicate the functionality of CTRL + NUMPAD+ on an extended keyboard
; This allows any keyboard that lacks the number pad [i.e. Tenkeyless (TKL), laptop, etc.] to use the Auto-Resize Details View File Explorer shortcut and requires AutoHotkey v1.1.33.11 or newer (not compatible with v2)

#Requires AutoHotkey v1.1.33.11

#If WinActive("ahk_class CabinetWClass")
^=::
Send {Blind}{NumpadAdd}
return
#If

; End.