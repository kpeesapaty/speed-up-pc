#Requires -RunAsAdministrator
# phase3_background_services.ps1 - Tame OneDrive sync and Windows Search indexer
# Usage: powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phase3_background_services.ps1)"

Write-Host "=== PHASE 3: BACKGROUND SERVICES ===" -ForegroundColor Cyan

# --- WINDOWS SEARCH INDEXER ---------------------------------------------------
Write-Host "`n[Search Indexer]" -ForegroundColor Yellow

$search = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
if ($search) {
    Write-Host "Current status: $($search.Status)"
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "WSearch" -StartupType Disabled
    Write-Host "Search Indexer: STOPPED and DISABLED" -ForegroundColor Red

    Write-Host @"

NOTE: Windows Search (Start menu search, file search) will still work - it just
won't index files proactively. First search after this may be slower but typing
in apps and terminal will be faster.

To re-enable later:
  Set-Service -Name WSearch -StartupType Automatic
  Start-Service -Name WSearch
"@
} else {
    Write-Host "WSearch service not found - may already be disabled." -ForegroundColor Green
}

# --- SUPERFETCH / SYSMAIN ----------------------------------------------------
Write-Host "`n[SysMain / SuperFetch]" -ForegroundColor Yellow
# On NVMe SSDs, SysMain provides minimal benefit and causes disk thrash
$sysmain = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
if ($sysmain) {
    Write-Host "Current status: $($sysmain.Status)"
    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "SysMain" -StartupType Disabled
    Write-Host "SysMain: STOPPED and DISABLED (not needed with NVMe SSD)" -ForegroundColor Red
}

# --- ONEDRIVE - PAUSE SYNC ---------------------------------------------------
Write-Host "`n[OneDrive]" -ForegroundColor Yellow

# Check if OneDrive is running
$od = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if ($od) {
    Write-Host "OneDrive is running (PID: $($od.Id))"

    # Pause sync by setting registry key (equivalent to right-click > Pause sync)
    $odRegPath = "HKCU:\Software\Microsoft\OneDrive\Accounts\Personal"
    if (Test-Path $odRegPath) {
        # Pause for 24 hours
        Set-ItemProperty -Path $odRegPath -Name "ThrottlePercentage" -Value 0 -ErrorAction SilentlyContinue
    }

    # Set OneDrive to NOT sync on metered connections and limit upload speed
    $odSettings = "HKCU:\Software\Microsoft\OneDrive"
    Set-ItemProperty -Path $odSettings -Name "EnableADAL" -Value 0 -ErrorAction SilentlyContinue

    Write-Host @"
OneDrive cannot be fully paused via script without killing it.
Manual steps (takes 10 seconds):
  1. Right-click OneDrive tray icon (system tray, bottom right)
  2. Click Settings > Sync and backup
  3. Under 'Sync', click 'Pause syncing' > 24 hours
  OR: Right-click OneDrive icon > Pause syncing > 24 hours

To permanently limit: Settings > Sync and backup > Manage backup > deselect folders
"@ -ForegroundColor White
} else {
    Write-Host "OneDrive is not running." -ForegroundColor Green
}

# --- WINDOWS UPDATE - PREVENT ACTIVE HOURS INTERFERENCE ---------------------
Write-Host "`n[Windows Update Active Hours]" -ForegroundColor Yellow
# Set active hours to your working hours so updates don't interrupt
$auPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
Set-ItemProperty -Path $auPath -Name "ActiveHoursStart" -Value 8  -ErrorAction SilentlyContinue
Set-ItemProperty -Path $auPath -Name "ActiveHoursEnd"   -Value 23 -ErrorAction SilentlyContinue
Write-Host "Windows Update active hours set to 8am-11pm (won't auto-restart during these hours)" -ForegroundColor Green

Write-Host "`n[DONE] Background services tamed." -ForegroundColor Green
