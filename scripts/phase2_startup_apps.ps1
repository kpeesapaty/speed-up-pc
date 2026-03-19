#Requires -RunAsAdministrator
# phase2_startup_apps.ps1 - Disable bloated startup programs
# Usage: powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phase2_startup_apps.ps1)"

Write-Host "=== PHASE 2: STARTUP APPS ===" -ForegroundColor Cyan

# Registry paths where startup entries live
$runKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)

# Apps to DISABLE (these are bloat - you can re-enable any manually)
$disableList = @(
    "EpicGamesLauncher",
    "NZXT CAM",
    "NZXT",
    "NZXT.CAM",
    "com.squirrel.WhatsApp.WhatsApp",
    "WhatsApp",
    "LogiDownloadAssistant",
    "Logitech Download Assistant",
    "OneDriveSetup"
)

# Apps to KEEP (do not touch these)
$keepList = @("LogiBolt", "LogiOptions", "RtkAudUService", "SecurityHealth", "OneDrive")

$disabled = @()
$notFound = @()

foreach ($key in $runKeys) {
    if (-not (Test-Path $key)) { continue }
    $entries = Get-ItemProperty $key

    foreach ($name in $disableList) {
        $val = $entries.$name
        if ($null -ne $val) {
            # Back up to a disabled key before removing
            $backupKey = $key -replace "\\Run$", "\Run_Disabled"
            if (-not (Test-Path $backupKey)) { New-Item $backupKey -Force | Out-Null }
            Set-ItemProperty -Path $backupKey -Name $name -Value $val -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue
            $disabled += "$name (from $key)"
            Write-Host "  DISABLED: $name" -ForegroundColor Red
        }
    }
}

# Also disable via Task Scheduler for Epic Games (it re-adds itself via scheduler)
$tasks = @(
    "EpicGamesLauncher",
    "EpicOnlineServices"
)
foreach ($task in $tasks) {
    $t = Get-ScheduledTask -TaskName "*$task*" -ErrorAction SilentlyContinue
    if ($t) {
        Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue
        Write-Host "  DISABLED scheduled task: $($t.TaskName)" -ForegroundColor Red
        $disabled += "Scheduled: $($t.TaskName)"
    }
}

# Kill currently running instances of these apps to free RAM now
$killNow = @("EpicGamesLauncher", "EpicWebHelper", "NZXT CAM", "cam_helper")
foreach ($proc in $killNow) {
    $p = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($p) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "  KILLED running process: $proc" -ForegroundColor Yellow
    }
}

Write-Host "`n[DONE] Disabled $($disabled.Count) startup entries:" -ForegroundColor Green
$disabled | ForEach-Object { Write-Host "  - $_" }

Write-Host "`nTo re-enable any of these, open Task Manager > Startup tab or restore from registry key:"
Write-Host "  HKCU\Software\Microsoft\Windows\CurrentVersion\Run_Disabled"
