#Requires AutoHotkey v2.0

; ==========================
; File Explorer AutoHotkey Hotkeys v2
; ==========================
; Runs in background, shows standard AHK tray icon
;
; Hotkeys:
; Ctrl + =           Auto-resize Details View columns
; Ctrl + Shift + C   Copy current folder path
; Ctrl + Shift + X   Copy selected file path(s)
; Ctrl + Alt + T     Open PowerShell 7 (Admin) in current folder
; Ctrl + Alt + E     Open selected file(s) in Notepad++ (x86)
; Ctrl + Shift + H   Show all hotkeys in a popup
; pwsh-user          Open non-admin PowerShell 7 from an Admin shell
;
; ==========================
; Run at Startup (Required for full functionality)
; ==========================
; The Ctrl + Alt + T hotkey requires this script to run as administrator.
; Using "Run as administrator" on a standard shortcut in shell:startup is
; silently ignored by Windows — the script will never load at boot.
; To run this script at startup with admin rights, you must use the UIA
; executable instead:
; 1. Create a shortcut in shell:startup
; 2. Set the shortcut Target to:
;      "C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe" "C:\Scripts\File_Explorer_AutoHotkey_Hotkeys_v2.ahk"
;      Use AutoHotkey64_UIA.exe for 64-bit systems (recommended) or AutoHotkey32_UIA.exe for 32-bit systems
;      (adjust the script path to match your actual location)
; 3. In shortcut Properties -> Advanced, enable "Run as administrator"
;
; Notes:
; - Ctrl + Alt + T (PowerShell Admin) will:
;       • Prompt for elevation if UAC is enabled
;       • Open non-admin if UAC is disabled
; - If you run File_Explorer_AutoHotkey_Hotkeys_v2.ahk using "Run as administrator," PowerShell will open as Admin
; - pwsh-user ensures you can still test scripts in a non-admin environment without closing elevated windows
; - Ctrl + Alt + E opens selected files in Notepad++ (x86 by default)  
;   If you use the 64-bit version, update the path in the script accordingly
;
; ==========================
; PowerShell non-admin helper
; ==========================
; If you don't have a PowerShell profile, do the following:
; 1. Open PowerShell and type: notepad $PROFILE
; 2. Add this function:
;       function pwsh-user {
;           # Opens a non-admin PowerShell 7 window, even from an Admin session
;           explorer.exe "C:\Program Files\PowerShell\7\pwsh.exe"
;       }
; 3. Save and close the profile
; 4. Reload the profile via: . $PROFILE and now pwsh-user will work as intended

SendMode("Input")
SetWorkingDir(A_ScriptDir)

; ==========================
; Tray icon — remove native tooltip at Windows API level
; ==========================
; Call once on startup to suppress the native Windows tray icon filename tooltip
RemoveTrayTip() {
	NID := Buffer(A_PtrSize * 5 + 40 + 448, 0)
	NumPut("UInt", A_PtrSize * 5 + 40 + 448, NID, 0)  ; cbSize
	NumPut("Ptr",  A_ScriptHwnd, NID, A_PtrSize)  ; hWnd
	NumPut("UInt", 0x404, NID, A_PtrSize * 2)  ; uID
	NumPut("UInt", 0x4, NID, A_PtrSize * 2 + 4)  ; uFlags = NIF_TIP
	; szTip left as empty string (already zeroed)
	DllCall("Shell32.dll\Shell_NotifyIconA", "UInt", 0x1, "Ptr", NID)  ; NIM_MODIFY
}
RemoveTrayTip()

; ==========================
; Tray hover tooltip GUI
; ==========================
global TooltipGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
TooltipGui.BackColor := "2C2C2C"
TooltipGui.SetFont("s9 cE8E8E8", "Consolas")
TooltipGui.Add("Text",,
	"File Explorer Hotkeys v2`n`n"
	"Ctrl + =           Auto-resize Details View columns`n"
	"Ctrl + Shift + C   Copy current folder path`n"
	"Ctrl + Shift + X   Copy selected file path(s)`n"
	"Ctrl + Alt + T     Open PowerShell 7 (Admin) in current folder`n"
	"Ctrl + Alt + E     Open selected file(s) in Notepad++ (x86)`n"
	"Ctrl + Shift + H   Show all hotkeys in a popup`n`n"
	"pwsh-user          Open non-admin PowerShell 7 from an Admin shell"
)
TooltipGui.Show("Hide")
global TooltipVisible := false
global LastMouseX := 0
global LastMouseY := 0

; Register a handler for tray icon mouse events (Windows message 0x404)
OnMessage(0x404, TrayIconMsg)

TrayIconMsg(wParam, lParam, msg, hwnd) {
	global TooltipVisible, LastMouseX, LastMouseY
	if (lParam = 0x200) {  ; WM_MOUSEMOVE — mouse is over tray icon
		if TooltipVisible  ; already visible, nothing to do
			return
		RECT := GetTrayIconRECT(A_ScriptHwnd)
		if !RECT  ; couldn't get tray icon position, bail out
			return
		; Measure GUI dimensions
		TooltipGui.Show("Hide")
		TooltipGui.GetPos(,, &gw, &gh)
		; Center GUI over tray icon, but clamp so it never goes off screen
		iconCenterX := (RECT.Left + RECT.Right) // 2
		xPos := iconCenterX - (gw // 2)
		xPos := Max(0, Min(xPos, A_ScreenWidth - gw))
		; Adjust the - 5 below to change the gap between the tooltip and Taskbar (0, - 2, or - 3 for a tighter fit)
		TooltipGui.Show("x" xPos " y" (RECT.Top - gh - 5) " NoActivate")
		TooltipVisible := true
		; Snapshot mouse position so HideIfMouseLeft can detect when it moves away
		MouseGetPos(&LastMouseX, &LastMouseY)
		; Start polling timer to detect when mouse leaves the tray icon
		SetTimer(HideIfMouseLeft, 250)
	}
}

HideIfMouseLeft() {
	global TooltipVisible, LastMouseX, LastMouseY
	MouseGetPos(&mx, &my)
	; If mouse has moved since last snapshot, assume it left the tray icon and hide the tooltip
	if (mx != LastMouseX || my != LastMouseY) {
		TooltipGui.Hide()
		TooltipVisible := false
		SetTimer(HideIfMouseLeft, 0)  ; stop the timer
	}
}

; Uses the Windows Shell API to get the exact screen coordinates of the tray icon
GetTrayIconRECT(hwnd) {
	static Size := 16 + 3 * A_PtrSize
	NOTIFYICONIDENTIFIER := Buffer(Size, 0)
	NumPut("UInt", Size, NOTIFYICONIDENTIFIER, 0)  ; cbSize
	NumPut("Ptr", hwnd, NOTIFYICONIDENTIFIER, A_PtrSize)  ; hWnd
	NumPut("UInt", 0x404, NOTIFYICONIDENTIFIER, 2 * A_PtrSize)  ; uID
	if !DllCall("Shell32\Shell_NotifyIconGetRect", "Ptr", NOTIFYICONIDENTIFIER, "Ptr", RECT := Buffer(16), "HRESULT")
		return {Left: NumGet(RECT, 0, "Int"), Top: NumGet(RECT, 4, "Int"), Right: NumGet(RECT, 8, "Int"), Bottom: NumGet(RECT, 12, "Int")}
	return false  ; returns false if the icon position couldn't be determined
}

; ==========================
; Hotkeys
; ==========================

; Ctrl + = → Auto-resize Details View columns
^=:: {
	Send("{LCtrl down}{NumpadAdd}{LCtrl up}")
}

; Ctrl + Shift + C → Copy current folder path
^+c:: {
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^l")
	Sleep(100)
	Send("^a")
	Sleep(50)
	Send("^c")
	ClipWait(2)
	local path := A_Clipboard
	Send("{Escape}")
	if (path = "") {
		A_Clipboard := ClipSaved
		MsgBox("Failed to copy folder path.")
	} else {
		A_Clipboard := path
	}
}

; Ctrl + Shift + X → Copy selected file path(s)
^+x:: {
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^c")
	if (!ClipWait(2)) {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in Explorer/Desktop.")
		Return
	}
	local paths := A_Clipboard
	if (paths = "") {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in Explorer/Desktop.")
		Return
	}
	; Clean up paths (trim each line)
	local files := StrSplit(paths, "`n")
	local joined := ""
	for file in files {
		local t := Trim(file)
		if (t != "")
			joined .= t "`n"
	}
	joined := RTrim(joined, "`n")
	A_Clipboard := joined
}

; Ctrl + Alt + T → Open PowerShell 7 (Admin) in current folder
^!t:: {
	; Check for an open Explorer window first
	hwndExplorer := WinExist("ahk_class CabinetWClass")
	if !hwndExplorer {
		MsgBox("No Explorer window detected.")
		Return
	}
	WinActivate("ahk_id " hwndExplorer)
	WinWaitActive("ahk_id " hwndExplorer,, 1)
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^l")
	Sleep(100)
	Send("^a")
	Sleep(50)
	Send("^c")
	ClipWait(2)
	local currentFolder := A_Clipboard
	Send("{Escape}")
	if (!FileExist(currentFolder))
		currentFolder := A_Desktop
	A_Clipboard := ClipSaved
	local psExe := "C:\Program Files\PowerShell\7\pwsh.exe"
	Run(psExe " -NoExit -Command Set-Location '" currentFolder "'",, "RunAs")
}

; Ctrl + Alt + E → Open selected file(s) in Notepad++ (x86)
^!e:: {
	local npp := "C:\Program Files (x86)\Notepad++\notepad++.exe"
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^c")
	if (!ClipWait(2)) {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in Explorer/Desktop.")
		Return
	}
	local paths := A_Clipboard
	if (paths = "") {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in Explorer/Desktop.")
		Return
	}
	local files := StrSplit(paths, "`n")
	for file in files {
		file := Trim(file)
		if (file != "")
			Run('"' npp '" "' file '"')
	}
	A_Clipboard := ClipSaved
}

; Ctrl + Shift + H → Show hotkeys popup
^+h:: {
	ShowHotkeys()
}

; ==========================
; Functions
; ==========================

ShowHotkeys() {
	MsgBox(
		"File Explorer Hotkeys v2`n`n"
		"Ctrl + =`t`tAuto-resize Details View columns`n"
		"Ctrl + Shift + C`tCopy current folder path`n"
		"Ctrl + Shift + X`tCopy selected file path(s)`n"
		"Ctrl + Alt + T`tOpen PowerShell 7 (Admin) in current folder`n"
		"Ctrl + Alt + E`tOpen selected file(s) in Notepad++ (x86)`n`n"
		"Tip: Use pwsh-user in PowerShell to open a non-admin shell"
	)
}

; End.