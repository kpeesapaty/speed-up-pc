#Requires -RunAsAdministrator
# run_all.ps1 - Master script: run benchmark, then all phases
# Usage from WSL: powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/run_all.ps1)"
# Usage from PowerShell (as Admin): .\scripts\run_all.ps1

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

function Run-Phase($name, $file) {
    Write-Host "`n" + ("-" * 60) -ForegroundColor DarkGray
    Write-Host "RUNNING: $name" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    $fullPath = Join-Path $scriptDir $file
    & powershell.exe -ExecutionPolicy Bypass -File $fullPath
}

# --- PRE-OPTIMIZATION BENCHMARK -----------------------------------------------
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  BEFORE benchmark (save this result)" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
& powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptDir "benchmark.ps1") "before"

# --- RUN ALL PHASES -----------------------------------------------------------
Run-Phase "Phase 1: Power Plan"            "phase1_power_plan.ps1"
Run-Phase "Phase 2: Startup Apps"          "phase2_startup_apps.ps1"
Run-Phase "Phase 3: Background Services"   "phase3_background_services.ps1"
Run-Phase "Phase 4: Defender Exclusions"   "phase4_defender_exclusions.ps1"
Run-Phase "Phase 6: NVIDIA/Display"        "phase6_nvidia_settings.ps1"

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  All Windows phases complete!" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

Write-Host "NEXT STEPS (manual - cannot be scripted):" -ForegroundColor Yellow
Write-Host "  1. REBOOT into BIOS and enable XMP/EXPO (most important step!)"
Write-Host "     Look for: AI Overclock Tuner / DOCP / XMP > Enable"
Write-Host "  2. Open NVIDIA Control Panel and set:"
Write-Host "     Vertical sync=Fast, Low Latency=Ultra, Power=Max Performance"
Write-Host "  3. After reboot, run in WSL:"
Write-Host "     bash ./scripts/phase5_wsl_config.sh"
Write-Host "     bash ./scripts/phase7_terminal_wsl_perf.sh"
Write-Host "  4. Then run the AFTER benchmark:"
Write-Host "     powershell.exe -ExecutionPolicy Bypass -File scripts/benchmark.ps1 after"
Write-Host ""
Write-Host "Results saved in: $projectDir\results\" -ForegroundColor Cyan
