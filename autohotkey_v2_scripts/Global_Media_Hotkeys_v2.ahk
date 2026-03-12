; This script provides global media control shortcuts for keyboards without dedicated media keys:
; Shift + F1 → Next track
; Shift + F2 → Previous track
; Shift + F3 → Stop playback
; Spacebar   → Play/Pause
; Requires AutoHotkey v2 (not compatible with v1)

#Requires AutoHotkey v2

; Next track
+F1::Send("{Media_Next}")

; Previous track
+F2::Send("{Media_Prev}")

; Stop playback
+F3::Send("{Media_Stop}")

; Play/Pause
Space::Send("{Media_Play_Pause}")

; End.