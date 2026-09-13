#Requires AutoHotkey v2
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Creates global media control shortcuts for keyboards without dedicated media keys
; NOTE: If you also run CTRL_Space_PlayPause_v2.ahk, disable the Ctrl + Spacebar hotkey in that script to avoid conflicts
;
; Hotkeys:
; Shift + F1        → Next track
; Shift + F2        → Previous track
; Shift + F3        → Stop playback
; Ctrl + Spacebar   → Play/Pause

; Next track
+F1:: Send("{Media_Next}")

; Previous track
+F2:: Send("{Media_Prev}")

; Stop playback
+F3:: Send("{Media_Stop}")

; Ctrl + Spacebar → Play/Pause
; Uses DllCall for hardware-level keypress — more reliable than Send {Media_Play_Pause} for apps like VLC
^Space:: {
	DllCall("keybd_event", "UInt", 0xB3, "UInt", 0, "UInt", 0, "UInt", 0)  ; key down
	DllCall("keybd_event", "UInt", 0xB3, "UInt", 0, "UInt", 2, "UInt", 0)  ; key up
}

; End.