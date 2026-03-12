; This script creates a CTRL + Spacebar global Play/Pause keyboard shortcut. Most media apps respond to this globally, but VLC requires its "Global Hotkeys" feature to be enabled in Tools → Preferences → Hotkeys for this shortcut to work when VLC is not focused.
; Requires AutoHotkey v1.1.33.11 or newer (not compatible with v2)

#Requires AutoHotkey v1.1.33.11

^Space::  ; CTRL + Spacebar
	; Send a real hardware Play/Pause key
	DllCall("keybd_event", "UInt", 0xB3, "UInt", 0, "UInt", 0, "UInt", 0)  ; key down
	DllCall("keybd_event", "UInt", 0xB3, "UInt", 0, "UInt", 2, "UInt", 0)  ; key up
return

; End.
