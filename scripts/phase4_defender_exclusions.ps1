# phase4_defender_check.ps1 - Diagnose if Defender is a bottleneck, then optionally exclude projects folder
# Conservative approach: diagnose first, add minimal exclusions only if warranted.
# Usage from WSL: powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phase4_defender_exclusions.ps1)"

Write-Host "=== PHASE 4: WINDOWS DEFENDER - DIAGNOSE FIRST ===" -ForegroundColor Cyan

# --- CHECK IF DEFENDER IS ACTUALLY CAUSING PROBLEMS --------------------------
Write-Host "`n[Checking MsMpEng (Defender) resource usage right now]" -ForegroundColor Yellow

$defender = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue
if ($defender) {
    $ramMB = [math]::Round($defender.WorkingSet / 1MB, 0)
    $cpu   = [math]::Round($defender.CPU, 1)
    Write-Host "  RAM used : $ramMB MB"
    Write-Host "  CPU-secs : $cpu  (cumulative since last boot - not a real-time %)"
    Write-Host ""
    if ($ramMB -gt 400) {
        Write-Host "  >> RAM usage is HIGH. Defender may be worth excluding your projects folder." -ForegroundColor Yellow
    } else {
        Write-Host "  >> RAM usage is normal. No strong evidence Defender is a bottleneck yet." -ForegroundColor Green
    }
} else {
    Write-Host "  MsMpEng not running - Defender may be disabled or using a different process." -ForegroundColor Gray
}

# --- CHECK WHAT DEFENDER IS CURRENTLY SCANNING -------------------------------
Write-Host "`n[Recent Defender scan activity (last 10 events)]" -ForegroundColor Yellow
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-Windows Defender/Operational'
        StartTime = (Get-Date).AddHours(-1)
    } -MaxEvents 10 -ErrorAction SilentlyContinue

    if ($events) {
        $events | Select-Object TimeCreated, Message | ForEach-Object {
            $short = ($_.Message -split "`n")[0]
            Write-Host "  $($_.TimeCreated.ToString('HH:mm:ss')) - $short"
        }
    } else {
        Write-Host "  No Defender events in the last hour - not actively scanning." -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not read Defender event log: $_" -ForegroundColor Gray
}

# --- SHOW CURRENT EXCLUSIONS ALREADY IN PLACE --------------------------------
Write-Host "`n[Current Defender exclusions already configured]" -ForegroundColor Yellow
$prefs = Get-MpPreference
if ($prefs.ExclusionPath) {
    Write-Host "  Paths   : $($prefs.ExclusionPath -join ', ')"
} else {
    Write-Host "  Paths   : (none)"
}
if ($prefs.ExclusionProcess) {
    Write-Host "  Process : $($prefs.ExclusionProcess -join ', ')"
} else {
    Write-Host "  Process : (none)"
}

# --- CONSERVATIVE EXCLUSION - PROJECTS FOLDER ONLY ---------------------------
Write-Host "`n[Conservative exclusion: projects folder only]" -ForegroundColor Yellow
Write-Host "This adds ONE path exclusion: C:\Users\krish\projects"
Write-Host "No process exclusions. No broad AppData exclusions."
Write-Host ""

$projectsPath = "C:\Users\krish\projects"

if (-not (Test-Path $projectsPath)) {
    Write-Host "  Path not found on Windows filesystem: $projectsPath" -ForegroundColor Gray
    Write-Host "  (Your projects may live inside WSL - in that case, no Windows exclusion needed)"
    Write-Host "  Skipping." -ForegroundColor Gray
} else {
    $confirm = Read-Host "  Add exclusion for $projectsPath ? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        try {
            Add-MpPreference -ExclusionPath $projectsPath -ErrorAction Stop
            Write-Host "  + Exclusion added: $projectsPath" -ForegroundColor Green
        } catch {
            Write-Host "  ! Failed (run as Admin): $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Skipped. Run this script again after completing other phases." -ForegroundColor Gray
        Write-Host "  If the benchmark still shows MsMpEng as a top CPU consumer after all"
        Write-Host "  other fixes, come back and add this exclusion then."
    }
}

Write-Host ""
Write-Host "[DONE] Phase 4 complete (diagnostic mode)." -ForegroundColor Green
Write-Host ""
Write-Host "When to revisit this: if after running all other phases the AFTER benchmark"
Write-Host "still shows MsMpEng in the top 5 CPU processes, THEN add the exclusion."
