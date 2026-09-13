#Requires AutoHotkey v1.1
; GitHub repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v1_scripts

; This script creates a Ctrl + Spacebar global Play/Pause keyboard shortcut
; Most media apps respond to this globally, but VLC requires its "Global Hotkeys" feature to be enabled
; in Tools → Preferences → Hotkeys for this shortcut to work when VLC is not focused
; NOTE: If you also run Global_Media_Hotkeys_v1.ahk, disable the Ctrl + Spacebar hotkey in that script to avoid conflicts

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

^Space::  ; Ctrl + Spacebar → Play/Pause
	; Send a real hardware Play/Pause key
	DllCall("keybd_event", "UInt", 0xB3, "UInt", 0, "UInt", 0, "UInt", 0)  ; key down
	DllCall("keybd_event", "UInt", 0xB3, "UInt", 0, "UInt", 2, "UInt", 0)  ; key up
Return

; End.