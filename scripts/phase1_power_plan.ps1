#Requires -RunAsAdministrator
# phase1_power_plan.ps1 - Switch to High Performance power plan
# Usage: powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phase1_power_plan.ps1)"

Write-Host "=== PHASE 1: POWER PLAN ===" -ForegroundColor Cyan

# Show current plan
Write-Host "`nCurrent power plan:" -ForegroundColor Yellow
powercfg /GetActiveScheme

# GUID for High Performance
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

# Try to activate High Performance (may need to be enabled first)
Write-Host "`nActivating High Performance plan..." -ForegroundColor Yellow
$result = powercfg -setactive $highPerfGuid 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "High Performance plan not found, creating it..." -ForegroundColor Yellow
    powercfg -duplicatescheme $highPerfGuid | Out-Null
    powercfg -setactive $highPerfGuid
}

# Fine-tune: disable CPU throttling within the plan
# Minimum processor state = 100% (no throttling)
powercfg -setacvalueindex $highPerfGuid SUB_PROCESSOR PROCTHROTTLEMIN 100
# Maximum processor state = 100%
powercfg -setacvalueindex $highPerfGuid SUB_PROCESSOR PROCTHROTTLEMAX 100
# Turn off hibernate (reduces latency spikes from disk writes)
powercfg -hibernate off

# Apply
powercfg -setactive $highPerfGuid

Write-Host "`nNew active plan:" -ForegroundColor Green
powercfg /GetActiveScheme

Write-Host "`n[DONE] Power plan set to High Performance with 100% CPU minimum." -ForegroundColor Green
Write-Host "Note: If you want AMD-optimised plan, download AMD chipset drivers from amd.com"
Write-Host "      which includes 'AMD Ryzen Balanced' - better than generic High Performance."
