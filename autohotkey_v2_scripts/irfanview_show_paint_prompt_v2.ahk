#Requires AutoHotkey v2.0
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; Press Ctrl + Alt + P to open IrfanView with a blank canvas and Paint dialog
^!p:: {
	local path64 := "C:\Program Files\IrfanView\i_view64.exe"
	local path32 := "C:\Program Files (x86)\IrfanView\i_view32.exe"
	local exePath := FileExist(path64) ? path64 : path32
	local exeName := FileExist(path64) ? "i_view64.exe" : "i_view32.exe"
	local tempImg := A_Temp "\ahk_blank_canvas.png"

	; Check for IrfanPaint plugin (Paint.dll) — required for F12 Paint dialog
	local pluginPath := (FileExist(path64) ? "C:\Program Files\IrfanView" : "C:\Program Files (x86)\IrfanView") "\Plugins\Paint.dll"
	if !FileExist(pluginPath) {
		MsgBox("IrfanPaint plugin (Paint.dll) not found.`nPlease install IrfanView plugins from https://www.irfanview.com")
		Return
	}

	; Create a blank white PNG canvas
	RunWait('powershell -NoProfile -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Drawing; $bmp = New-Object System.Drawing.Bitmap(800,600); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::White); $bmp.Save(\"' tempImg '\", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()"')
	if !FileExist(tempImg) {
		MsgBox("Failed to create blank canvas. Please check PowerShell is available.")
		Return
	}

	; Launch IrfanView with the blank canvas
	Run('"' exePath '" "' tempImg '"')

	; Wait for IrfanView to exist by executable name
	if !WinWait("ahk_exe " exeName,, 10) {
		MsgBox("IrfanView failed to open.")
		Return
	}

	; Force focus
	WinActivate("ahk_exe " exeName)
	WinWaitActive("ahk_exe " exeName,, 5)

	; Give IrfanView time to fully load the image and plugins before sending F12
	; Lower values (i.e. 125 or 250) may work on faster machines — increase if Paint dialog fails to appear
	Sleep(500)

	; Send F12 directly to IrfanView without stealing focus
	local hwnd := WinExist("ahk_exe " exeName)
	PostMessage(0x100, 0x7B, 0,, "ahk_id " hwnd)  ; WM_KEYDOWN, VK_F12
	Sleep(50)
	PostMessage(0x101, 0x7B, 0,, "ahk_id " hwnd)  ; WM_KEYUP, VK_F12
}