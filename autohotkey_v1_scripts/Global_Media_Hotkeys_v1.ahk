; This script provides global media control shortcuts for keyboards without dedicated media keys:
; Shift + F1        → Next track
; Shift + F2        → Previous track
; Shift + F3        → Stop playback
; Ctrl + Spacebar   → Play/Pause
; Requires AutoHotkey v1.1.33.11 or newer (not compatible with v2)

#Requires AutoHotkey v1.1.33.11

; Next track
+F1::Send {Media_Next}

; Previous track
+F2::Send {Media_Prev}

; Stop playback
+F3::Send {Media_Stop}

; Play/Pause
^Space::Send {Media_Play_Pause}

; End.