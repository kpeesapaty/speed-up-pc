# JUGGERNAUT Speed-Up Plan

## Ad-hoc Fixes Log

### Taskbar flicker on login (silver ↔ black) — fixed 2026-03-17

**Symptom:** Taskbar and Start button flickered between silver/light and black/dark on every login.

**Root cause:** Registry mismatch between two keys that both control accent color on the taskbar:
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\ColorPrevalence = 0` (accent OFF)
- `HKCU\Software\Microsoft\Windows\DWM\ColorPrevalence = 1` (accent ON)

Windows resolves the conflict at shell load time, causing the visible flash.

**Fix applied:**
```powershell
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'ColorPrevalence' -Value 1
```

Both keys now `= 1`. No third-party tools involved — pure Windows registry drift.

---

## ⚠ Open Issue: NVMe Write Speed Below Spec

**Sabrent Rocket 4.0 1TB rated:** ~7000 MB/s read / ~6500 MB/s write
**Observed (CrystalDiskMark, post-optimisation):** ~5000 MB/s read / ~1000-1500 MB/s write

Write is 4-6x below rated spec. Drive was at 83% full during first test (SLC cache starved), then GC running during second test after freeing ~380GB. **Awaiting clean retest after idle GC completes.**

Suspected causes to rule out in order:
1. GC still running post-large-delete — retest after 30-60min idle
2. Windows Defender scanning NVMe writes (partial fix: added %TEMP% exclusion)
3. PCIe slot/gen mismatch — unlikely, read speed confirms PCIe 4.0 working
4. Drive health — run `crystaldiskinfo` to check reallocated sectors / health status

---

**Machine:** AMD Ryzen 7 5700X | RTX 3080 | 32GB RAM | Sabrent Rocket 4.0 1TB NVMe | Windows 11 25H2
**Displays:** 2× 4K 60Hz (HDMI + DisplayPort)
**Problem:** Input lag, screen update lag, inconsistent spikes — especially noticeable in terminal

---

## Root Causes (Diagnosed)

| # | Problem | Evidence | Impact |
|---|---|---|---|
| 1 | **RAM at 2400MHz — XMP not enabled** | Task Manager shows 2400MHz; kit is almost certainly rated 3200–3600MHz | Ryzen Infinity Fabric runs at half RAM speed — bottlenecks everything |
| 2 | **Power Plan: Balanced** | `powercfg /GetActiveScheme` returned Balanced GUID | CPU parks cores aggressively, must wake on every keypress → input lag |
| 3 | **OneDrive actively syncing** | 650 CPU-seconds consumed in snapshot, 458MB RAM | CPU spikes causing inconsistent lag bursts |
| 4 | **Windows Search indexer running** | SearchProtocolHost + SearchIndexer = 629 CPU-seconds | Disk + CPU spikes |
| 5 | **8+ bloated startup apps** | Epic, NZXT CAM, WhatsApp, 3× Logitech, OneDrive, Claude | ~1GB RAM + constant background CPU at boot |
| 6 | **VSync: On** | Confirmed by user | Any frame >16.67ms drops to 30fps — causes visible stutter |
| 7 | **No WSL memory limit** | No `.wslconfig` found | WSL can grab up to 50% of RAM dynamically |

---

## Execution Order (priority = impact)

```
BIOS  →  Phase 1  →  Phase 2  →  Phase 3  →  Phase 4  →  WSL restart  →  Phase 5–7
```

Run the **BEFORE benchmark first**, then work through phases, then run **AFTER benchmark**.

---

## Step 0 — Run BEFORE Benchmark

From WSL:
```bash
cd /home/krish/projects/PythonProject/speed-up-pc
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/benchmark.ps1)" before
```

This saves a timestamped report to `./results/benchmark_before_*.txt`.

---

## Step 1 — BIOS: Enable XMP (DO THIS FIRST — biggest impact)

**Cannot be scripted. Takes 5 minutes.**

1. Save all work and restart
2. Spam `DEL` or `F2` during boot to enter BIOS
3. Find one of these settings (name varies by motherboard brand):
   - MSI: `OC` tab → `XMP`
   - ASUS: `Ai Tweaker` → `AI Overclock Tuner` → `XMP`
   - Gigabyte: `MIT` → `Extreme Memory Profile (XMP)`
4. Set it to **Profile 1** (your kit's rated speed — likely 3200 or 3600MHz)
5. Save and boot (`F10`)
6. Verify in Task Manager → Performance → Memory: should show 3200+ MHz

> **Why this matters:** Your RAM runs at 2400MHz. Ryzen's Infinity Fabric (the interconnect linking CPU cores, memory controller, and cache) runs at *half* your memory speed — so currently 1200MHz. Enabling XMP to 3600MHz doubles this to 1800MHz, improving CPU-to-memory latency, multi-core communication, and everything that touches RAM.

---

## Phase 1 — Power Plan

**Script:** `scripts/phase1_power_plan.ps1`
**Requires:** Admin PowerShell

```powershell
# From Admin PowerShell
.\scripts\phase1_power_plan.ps1

# OR from WSL
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/phase1_power_plan.ps1)"
```

**What it does:**
- Switches to High Performance power plan
- Sets CPU minimum state to 100% (no core parking)
- Disables hibernate (removes latency-causing disk flush)

**Manual follow-up:** Download AMD chipset drivers from amd.com — the package includes **AMD Ryzen Balanced** power plan which is better than generic High Performance for this CPU.

---

## Phase 2 — Startup Apps

**Script:** `scripts/phase2_startup_apps.ps1`
**Requires:** Admin PowerShell

```powershell
.\scripts\phase2_startup_apps.ps1
```

**Disables:**
- EpicGamesLauncher + scheduled task (open it manually when gaming)
- NZXT CAM (replace with HWiNFO64 if you want monitoring — far lighter)
- WhatsApp auto-start
- Logitech Download Assistant (drivers already installed)
- OneDriveSetup duplicate entries

**Keeps:** LogiBolt, LogiOptions, RtkAudUService, SecurityHealth, OneDrive
**Backup:** Disabled entries are backed up to registry `Run_Disabled` key before removal

---

## Phase 3 — Background Services

**Script:** `scripts/phase3_background_services.ps1`
**Requires:** Admin PowerShell

```powershell
.\scripts\phase3_background_services.ps1
```

**What it does:**
- **Stops + disables Windows Search indexer** — proactive file indexing paused. Search still works, just slower on first query.
- **Stops + disables SysMain (SuperFetch)** — not useful on NVMe SSDs, causes background disk reads
- **Pauses OneDrive** — script handles what it can; see manual step below
- **Sets Windows Update active hours** to 8am–11pm so updates don't restart mid-session

**OneDrive manual step (10 seconds):**
1. Right-click OneDrive tray icon → Settings → Sync and backup
2. Click "Pause syncing" → 24 hours
   OR: Deselect heavy folders from backup entirely

---

## Phase 4 — Windows Defender (Diagnose First)

**Script:** `scripts/phase4_defender_exclusions.ps1`
**Requires:** Admin PowerShell (for the optional exclusion step)

```powershell
.\scripts\phase4_defender_exclusions.ps1
```

**Conservative approach:** This script diagnoses whether Defender is actually a bottleneck before touching anything. It shows current MsMpEng RAM/CPU usage, recent scan events, and existing exclusions.

If Defender looks fine, skip the exclusion and move on. Only adds an exclusion if you confirm it interactively — and only for `C:\Users\krish\projects` (one targeted path, no process exclusions).

**When to revisit:** If the AFTER benchmark still shows MsMpEng in the top 5 CPU processes after all other phases are done, come back and add the exclusion then.

---

## Phase 5 — WSL Config

**Script:** `scripts/phase5_wsl_config.sh`
**Run from WSL (bash, not PowerShell)**

```bash
bash ./scripts/phase5_wsl_config.sh
```

**What it does:**
- Caps WSL memory at **8GB** (leaves 24GB for Windows — currently no cap)
- Limits WSL to **6 CPU cores** (leaves 2 dedicated to Windows responsiveness)
- Enables `autoMemoryReclaim=gradual` — WSL releases memory back to Windows when idle
- Enables `sparseVhd` — virtual disk only uses space it needs
- Sets swappiness to 10 (reduces WSL swap thrash)

**After running, restart WSL:**
```bash
# From Windows PowerShell
wsl --shutdown
# Then reopen your terminal
```

---

## Phase 6 — NVIDIA & Display Settings

**Script:** `scripts/phase6_nvidia_settings.ps1` (handles what's scriptable)
**Requires:** PowerShell (no Admin needed)

```powershell
.\scripts\phase6_nvidia_settings.ps1
```

**Scriptable (auto-applied):**
- Enables Hardware-Accelerated GPU Scheduling if not already on
- Disables fullscreen optimizations (reduces DWM compositor overhead)
- Disables Xbox Game Bar capture
- Sets `SystemResponsiveness=0` (max foreground app priority)

**Manual in NVIDIA Control Panel (2 minutes):**

1. Right-click desktop → NVIDIA Control Panel
2. **Manage 3D Settings → Global Settings:**
   - Vertical sync → **Fast** (not "On" — "On" drops to 30fps if any frame exceeds 16.67ms)
   - Low Latency Mode → **Ultra**
   - Power management mode → **Optimal power** *(reverted 2026-03-17 — max performance is wasteful at idle; GPU still boosts to full clocks under load)*
3. **Display → Change resolution:**
   - Verify both monitors are at 60Hz (not 59Hz — some cables cause this)
   - If DisplayPort monitor shows limited options, try a different DP cable (DP 1.4 needed for 4K@60Hz with DSC)

---

## Phase 7 — Terminal & Shell Performance

**Script:** `scripts/phase7_terminal_wsl_perf.sh`
**Run from WSL**

```bash
bash ./scripts/phase7_terminal_wsl_perf.sh
```

**Diagnoses:**
- Shell startup time (if >300ms your .zshrc has slow plugins)
- Which Oh My Zsh plugins are slow
- Powerlevel10k instant prompt config
- Whether your projects are on Windows vs Linux filesystem (big perf difference)
- Windows Terminal rendering settings

**Key insight:** If your project files live at `/mnt/c/Users/krish/projects` (Windows filesystem), every file operation from WSL crosses the 9P filesystem bridge and is 10–50× slower than if they lived at `~/projects` (Linux filesystem). The lag you feel in the terminal may be partly this.

---

## Step 8 — Run AFTER Benchmark

After all phases + reboot:

```bash
cd /home/krish/projects/PythonProject/speed-up-pc
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/benchmark.ps1)" after
```

Compare `./results/benchmark_before_*.txt` vs `./results/benchmark_after_*.txt`.

**Expected improvements:**
| Metric | Before | Expected After |
|---|---|---|
| RAM speed | 2400 MHz | 3200–3600 MHz |
| CPU clock (under load) | 3401 MHz (base) | 4400–4600 MHz (boost) |
| CPU benchmark | baseline | 20–35% faster |
| Memory benchmark | baseline | 30–50% faster (RAM speed dependent) |
| Input lag | noticeable | minimal to none |
| Startup app RAM | ~1GB wasted | freed |

---

## Run Everything at Once

To run all Windows phases in sequence (still need BIOS + manual steps):

```powershell
# Admin PowerShell or from WSL:
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/run_all.ps1)"
```

This runs the before-benchmark, all phases, then prints remaining manual steps.

---

## Remaining Manual Steps (checklist)

- [ ] BIOS: Enable XMP/EXPO (Step 1 — most important)
- [ ] AMD chipset drivers: download from amd.com → includes Ryzen power plan
- [ ] NVIDIA Control Panel: VSync=Fast, Low Latency=Ultra, Power=Max Performance
- [ ] OneDrive: pause sync or trim backed-up folders
- [ ] After reboot: run `bash ./scripts/phase5_wsl_config.sh` then `wsl --shutdown`
- [ ] Run AFTER benchmark and compare

---

## If You Want to Go Further (optional)

**Core Isolation / Memory Integrity** — Windows Security → Device Security → Core Isolation
If "Memory Integrity" is ON, disabling it reduces virtualization overhead. Tradeoff: minor security reduction. Your call.

**Clean NVIDIA driver install** — if you've been updating drivers over old ones for a long time:
1. Download DDU (Display Driver Uninstaller) from Wagnardsoft
2. Boot to Safe Mode, run DDU (clean removal)
3. Reinstall latest driver fresh

**AMD Chipset drivers** — separate from GPU drivers, controls Ryzen scheduler, USB, PCIe, power states. Check if yours are over 6 months old at amd.com.
