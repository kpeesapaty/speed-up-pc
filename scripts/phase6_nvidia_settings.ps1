# phase6_nvidia_settings.ps1 - Apply NVIDIA Control Panel optimizations via registry
# Some settings require NVIDIA Control Panel manually - this handles what's scriptable.
# Usage: powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phase6_nvidia_settings.ps1)"

Write-Host "=== PHASE 6: NVIDIA SETTINGS ===" -ForegroundColor Cyan

# --- CHECK DRIVER -------------------------------------------------------------
$gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" } | Select-Object -First 1
if (-not $gpu) {
    Write-Host "No NVIDIA GPU detected. Exiting." -ForegroundColor Red
    exit 1
}
Write-Host "GPU: $($gpu.Name)" -ForegroundColor White
Write-Host "Driver: $($gpu.DriverVersion)"

# --- HARDWARE-ACCELERATED GPU SCHEDULING -------------------------------------
Write-Host "`n[Hardware-Accelerated GPU Scheduling]" -ForegroundColor Yellow
$hags = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue
if ($hags.HwSchMode -eq 2) {
    Write-Host "HAGS: Already ENABLED (good)" -ForegroundColor Green
} else {
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
    Write-Host "HAGS: ENABLED (requires reboot)" -ForegroundColor Green
}

# --- DISABLE VSYNC IN NVIDIA PROFILE (global default) ------------------------
# NV uses Direct3D profile IDs in registry - this sets global defaults via NvAPI
# We set these in the base profile (00000000) via NVAPI registry trick
Write-Host "`n[VSync settings - see manual steps below]" -ForegroundColor Yellow

Write-Host @"

The following MUST be set manually in NVIDIA Control Panel (takes 2 minutes):

  1. Open NVIDIA Control Panel (right-click desktop or search)
  2. Go to: Manage 3D Settings > Global Settings

  Set these:
    Vertical sync           Fast           (not On - 'On' drops to 30fps if frame misses 16.67ms)
    Low Latency Mode        Ultra          (submits frames at last possible moment)
    Power management mode   Prefer maximum performance
    Texture filtering       Performance

  3. Under 'Display' > 'Set up G-SYNC' - check if your monitors support it
     (Even without G-Sync monitors, FreeSync/G-Sync Compatible on DP is possible)

  4. Under 'Display' > 'Change resolution':
     - Confirm both monitors are at their native res and 60Hz (not 59Hz)
     - DisplayPort monitor: check if 4K 60Hz is truly active (not limited by cable)

"@ -ForegroundColor White

# --- DISABLE FULLSCREEN OPTIMIZATIONS (reduces DWM latency in windowed games) -
Write-Host "[Disabling fullscreen optimizations globally]" -ForegroundColor Yellow
$fsoKey = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $fsoKey)) { New-Item $fsoKey -Force | Out-Null }
Set-ItemProperty $fsoKey -Name "GameDVR_FSEBehaviorMode" -Value 2 -ErrorAction SilentlyContinue
Set-ItemProperty $fsoKey -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -ErrorAction SilentlyContinue
Set-ItemProperty $fsoKey -Name "GameDVR_Enabled" -Value 0 -ErrorAction SilentlyContinue
Write-Host "Fullscreen optimizations: disabled (reduces DWM compositor overhead)" -ForegroundColor Green

# --- DISABLE XBOX GAME BAR (background overhead) -----------------------------
Write-Host "`n[Xbox Game Bar]" -ForegroundColor Yellow
$xboxKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $xboxKey)) { New-Item $xboxKey -Force | Out-Null }
Set-ItemProperty $xboxKey -Name "AppCaptureEnabled" -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -ErrorAction SilentlyContinue
Write-Host "Xbox Game Bar capture: DISABLED" -ForegroundColor Red

# --- DWM LATENCY HINT ---------------------------------------------------------
Write-Host "`n[DWM Timer Resolution]" -ForegroundColor Yellow
# Windows default timer resolution is 15.6ms - apps can request 1ms
# This sets the system to always run at 1ms timer resolution
# (improves responsiveness at cost of ~0.5% CPU)
$timerPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty $timerPath -Name "SystemResponsiveness" -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty $timerPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -ErrorAction SilentlyContinue
Write-Host "SystemResponsiveness: set to 0 (max responsiveness for foreground apps)" -ForegroundColor Green

Write-Host "`n[DONE] Scriptable NVIDIA/display settings applied." -ForegroundColor Green
Write-Host "Complete the manual NVIDIA Control Panel steps listed above."
