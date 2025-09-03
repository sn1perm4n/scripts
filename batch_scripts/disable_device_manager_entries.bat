@echo off

@REM This script disables unnecessary devices I don't use (and deletes an invisible monitor) in Device Manager. Some devices get re-enabled (or reappear) every time the Nvidia driver is updated.
@REM Use the following command to find the devices in question (use the InstanceId in pnputil):
@REM pnputil /enum-devices can also be used (recommend outputting the command to a file and searching said file):
@REM pnputil /enum-devices > C:\Users\<PROFILE>\Desktop\pnputil_output.txt
@REM Interesting PowerShell command: Get-PnpDevice | Format-Table -AutoSize | findstr "Error"

@REM Realtek Digital Output (Realtek(R) Audio) - This InstanceId changes, making the following command worthless:
@REM pnputil /disable-device "SWD\MMDEVAPI\{0.0.0.00000000}.{5266fb3b-3d6c-4574-9f0a-ac3582107172}"

@REM NOTE: I've migrated this script to a more robust PowerShell version

@REM A-Volute Nh3 Audio Effects Component
pnputil /disable-device "SWD\DRIVERENUM\{CE86418F-53D0-B4E5-36B3-3D0907CFA3B4}#AVOLUTE_NH3APO&5&3AE76C9C&C"

@REM Dell AW2518HF(DisplayPort)
@REM Invisible monitor entry after Nvidia driver upgrade
pnputil /remove-device "DISPLAY\DELA103\1&8713bca&0&UID0"

@REM Nahimic Mirroring Component
pnputil /disable-device "SWD\DRIVERENUM\{CE86418F-53D0-B4E5-36B3-3D0907CFA3B4}#NAHIMIC_MIRRORING&5&3AE76C9C&C"

@REM Nahimic mirroring device
pnputil /disable-device "ROOT\MEDIA\0000"

@REM NVIDIA High Definition Audio
pnputil /disable-device "HDAUDIO\FUNC_01&VEN_10DE&DEV_009A&SUBSYS_38424897&REV_1001\5&37afc14e&0&0001"

@REM NVIDIA Virtual Audio Device (Wave Extensible) (WDM)
pnputil /disable-device "ROOT\UNNAMED_DEVICE\0000"

:end

@REM End.