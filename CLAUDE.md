# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Windows PC performance optimization toolkit for a specific machine (AMD Ryzen 7 5700X | RTX 3080 | 32GB RAM | Windows 11). It consists of PowerShell scripts run on Windows and bash scripts run from WSL2.

## Running Scripts

**From WSL (recommended):**
```bash
# Run all Windows phases at once (requires Admin elevation via UAC prompt)
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/run_all.ps1)"

# Run a single phase
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phaseN_*.ps1)"

# Run WSL/bash phases directly
bash ./scripts/phase5_wsl_config.sh
bash ./scripts/phase7_terminal_wsl_perf.sh
```

**From Admin PowerShell (Windows):**
```powershell
.\scripts\run_all.ps1
# or individual: .\scripts\phase1_power_plan.ps1
```

## Benchmark Commands

```bash
# Before optimization
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/benchmark.ps1)" before

# After optimization
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/benchmark.ps1)" after
```

Results are saved to `./results/benchmark_before_*.txt` and `./results/benchmark_after_*.txt`.

## Architecture

- **`scripts/phase1–4, 6`** — PowerShell scripts, require Windows Admin. Run via `run_all.ps1` or individually.
- **`scripts/phase5, 7`** — Bash scripts, run directly in WSL2.
- **`scripts/benchmark.ps1`** — Captures system state (RAM speed, CPU clocks, top processes) to `./results/`.
- **`scripts/run_all.ps1`** — Orchestrates all PowerShell phases in order + prints remaining manual steps.
- **`speed-up-plan.md`** — Full documentation of root causes, what each phase does, and manual steps that cannot be scripted (BIOS XMP, NVIDIA Control Panel).

## Execution Order

```
BIOS (manual) → Phase 1 → Phase 2 → Phase 3 → Phase 4 → WSL restart → Phase 5 → Phase 6 → Phase 7
```

Phase 5 and 7 must run **after** WSL restart (`wsl --shutdown` from Windows PowerShell).

## Key Constraints

- Phase 4 (`phase4_defender_exclusions.ps1`) is **diagnostic-first** — it only adds Defender exclusions interactively if confirmed. Do not modify it to auto-apply exclusions.
- Phase 2 backs up disabled startup registry entries to `Run_Disabled` key before removing them.
- WSL scripts modify `~/.wslconfig` — always check the existing file before writing new values.
