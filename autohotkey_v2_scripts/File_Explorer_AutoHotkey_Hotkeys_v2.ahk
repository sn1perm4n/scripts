#Requires AutoHotkey v2
; Github repository (Reed Waller): https://github.com/sn1perm4n/scripts/tree/main/autohotkey_v2_scripts

; ==========================
; File Explorer AutoHotkey Hotkeys v2
; ==========================
; Hotkeys:
; Ctrl + =           Auto-resize Details View columns
; Ctrl + Shift + C   Copy current folder path
; Ctrl + Shift + X   Copy selected file path(s)
; Ctrl + Alt + T     Open PowerShell (Admin) in current folder or Desktop
; Ctrl + Alt + E     Open selected file(s) in Notepad++ (x86)
; Ctrl + Alt + V     Open selected file(s) in VSCode
; Ctrl + Shift + H   Show all hotkeys in a popup
; pwsh-user          Open non-admin PowerShell window from an Admin shell (defined in PowerShell profile)
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
;      "C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe" "\PATH\TO\File_Explorer_AutoHotkey_Hotkeys_v2.ahk"
;      Use AutoHotkey64_UIA.exe for 64-bit systems (recommended) or AutoHotkey32_UIA.exe for 32-bit systems
;      (adjust the script path to match your actual location)
; 3. In shortcut Properties -> Advanced, enable "Run as administrator"
;
; NOTE: If UAC is enabled, a UAC prompt will appear on every reboot. This is
;       unavoidable with the UIA approach. Consider using Task Scheduler instead
;       if this is undesirable. See v1 script for Task Scheduler setup instructions,
;       using this executable instead:
;       "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
;
; ==========================
; Notes:
; ==========================
; - Runs in background, shows standard AHK tray icon
; - Ctrl + Alt + T (PowerShell Admin) will:
;       • Prompt for elevation if UAC is enabled
;       • Open non-admin if UAC is disabled
; - If you run File_Explorer_AutoHotkey_Hotkeys_v2.ahk using "Run as administrator," PowerShell will open as Admin
; - pwsh-user ensures you can still test scripts in a non-admin environment without closing elevated windows
; - Ctrl + Alt + E opens selected files in Notepad++ (x86 by default)
;   If you use the 64-bit version, update the path in the script accordingly
; - Ctrl + Alt + V opens selected files in VSCode (per-user install path by default)
;   If you have a system-wide install, update the path in the script accordingly
;
; ==========================
; PowerShell non-admin helper
; ==========================
; If you don't have a PowerShell profile, do the following:
; 1. Open PowerShell 5 AND PowerShell 7 and run: notepad $PROFILE
;    (click Yes if prompted to create a new file)
;    NOTE: If PowerShell says it cannot find the $PROFILE path, run this first:
;          New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force
; 2. Add this function to both profiles:
;       function pwsh-user {
;           # Opens a non-admin PowerShell window, even from an Admin session
;           # Matches the PowerShell version of the current session (5 or 7)
;           # NOTE: New window opens in the default directory, not the current one
;           $currentPwsh = Join-Path $PSHOME "pwsh.exe"
;           if (-not (Test-Path $currentPwsh)) {
;               $currentPwsh = Join-Path $PSHOME "powershell.exe"
;           }
;           explorer.exe $currentPwsh
;       }
; 3. Save and close both profiles
; 4. Reload each profile via: . $PROFILE (or close/re-open PowerShell) and now pwsh-user will work as intended


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
	"Ctrl + Alt + T     Open PowerShell (Admin) in current folder or Desktop`n"
	"Ctrl + Alt + E     Open selected file(s) in Notepad++ (x86)`n"
	"Ctrl + Alt + V     Open selected file(s) in VSCode`n"
	"Ctrl + Shift + H   Show all hotkeys in a popup`n`n"
	"pwsh-user          Open non-admin PowerShell from an Admin shell"
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
		RemoveTrayTip()  ; re-suppress native tooltip on every hover
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
		xPos := Max(5, Min(xPos, A_ScreenWidth - gw - 5))
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
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	local paths := A_Clipboard
	if (paths = "") {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in File Explorer/Desktop.")
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

; Ctrl + Alt + T → Open PowerShell (Admin) in current folder or Desktop
; NOTE: If you want a non-admin PowerShell 5 or 7 window instead, use the pwsh-user function (documented above)
^!t:: {
	local currentFolder := ""

	; Check if the Desktop is the active/focused window first
	if WinActive("ahk_class WorkerW") || WinActive("ahk_class Progman") {
		currentFolder := A_Desktop
	} else {
		; Check for an open File Explorer window
		hwndExplorer := WinExist("ahk_class CabinetWClass")
		if hwndExplorer {
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
			currentFolder := A_Clipboard
			Send("{Escape}")
			if (!FileExist(currentFolder))
				currentFolder := A_Desktop
			A_Clipboard := ClipSaved
		} else {
			MsgBox("No File Explorer/Desktop window detected.")
			Return
		}
	}

	; Open PowerShell as Administrator (falls back to PowerShell 5 if 7 is not installed)
	local psExe := "C:\Program Files\PowerShell\7\pwsh.exe"
	if (!FileExist(psExe))
		psExe := "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
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
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	local paths := A_Clipboard
	if (paths = "") {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	; Build a single command with all file paths in correct tab order
	local files := StrSplit(paths, "`n")
	local reversed := []
	loop files.Length
		reversed.Push(files[files.Length - A_Index + 1])
	local args := ""
	for file in reversed {
		file := Trim(file, " `t`r`n")  ; explicitly strip carriage returns and newlines
		if (file != "")
			args .= '"' file '" '
	}
	Run('"' npp '" ' Trim(args))
	A_Clipboard := ClipSaved
}

; Ctrl + Alt + V → Open selected file(s) in VSCode
^!v:: {
	; Uses 'code' via cmd.exe rather than Code.exe directly — handles multiple files and reuses existing window correctly
	; A_UserName dynamically resolves to the current Windows username at runtime (per-user install path)
	local ClipSaved := ClipboardAll()
	A_Clipboard := ""
	Send("^c")
	if (!ClipWait(2)) {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	local paths := A_Clipboard
	if (paths = "") {
		A_Clipboard := ClipSaved
		MsgBox("No file selected in File Explorer/Desktop.")
		Return
	}
	; Build a single command with all file paths in correct tab order
	; NOTE: Tab/open order depends on Windows clipboard reporting order and may not always match
	; click order — Desktop selections tend to be most reliable for ordered multi-file selection
	local files := StrSplit(paths, "`n")
	local reversed := []
	loop files.Length
		reversed.Push(files[files.Length - A_Index + 1])
	local args := ""
	for file in reversed {
		file := Trim(file)
		if (file != "")
			args .= '"' file '" '
	}
	; Run via cmd.exe using 'code' from PATH — correctly reuses existing VSCode window
	RunWait(A_ComSpec ' /c code ' Trim(args),, "Hide")
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
		"Ctrl + Alt + T`tOpen PowerShell (Admin) in current folder or Desktop`n"
		"Ctrl + Alt + E`tOpen selected file(s) in Notepad++ (x86)`n"
		"Ctrl + Alt + V`tOpen selected file(s) in VSCode`n`n"
		"Tip: Use pwsh-user in PowerShell to open a non-admin shell"
	)
}

; End.