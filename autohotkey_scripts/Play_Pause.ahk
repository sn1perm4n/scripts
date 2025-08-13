#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; This script sets Left-Ctrl + Spacebar as a play/pause keyboard shortcut

^Space::
	Send, {vk_MEDIA_PLAY_PAUSE}
	return