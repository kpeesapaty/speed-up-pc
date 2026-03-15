# benchmark.ps1 - Run BEFORE and AFTER applying optimizations
# Usage (from WSL): powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./scripts/benchmark.ps1)"
# Usage (from PowerShell): .\scripts\benchmark.ps1
# Saves a timestamped report to ./results/

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$label = if ($args[0]) { $args[0] } else { "snapshot" }
$outFile = Join-Path $PSScriptRoot "..\results\benchmark_${label}_${timestamp}.txt"
$outFile = [System.IO.Path]::GetFullPath($outFile)

function Write-Section($title) {
    $line = "=" * 60
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    "`n$line`n  $title`n$line"
}

$report = @()
$report += "PC PERFORMANCE BENCHMARK REPORT"
$report += "Label   : $label"
$report += "Time    : $(Get-Date)"
$report += "Machine : $env:COMPUTERNAME"
$report += ""

# --- SYSTEM SNAPSHOT ----------------------------------------------------------
$report += Write-Section "1. SYSTEM SNAPSHOT"

$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$ram = Get-WmiObject Win32_PhysicalMemory
$os  = Get-WmiObject Win32_OperatingSystem

$totalRAM  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeRAM   = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedRAM   = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
$ramSpeed  = ($ram | Select-Object -First 1).Speed

$report += "CPU              : $($cpu.Name.Trim())"
$report += "CPU Max Clock    : $($cpu.MaxClockSpeed) MHz"
$report += "CPU Current Clock: $($cpu.CurrentClockSpeed) MHz   should be near MaxClockSpeed under load"
$report += "CPU Load Now     : $($cpu.LoadPercentage)%"
$report += "RAM Total        : $totalRAM GB"
$report += "RAM Used         : $usedRAM GB"
$report += "RAM Free         : $freeRAM GB"
$report += "RAM Speed        : $ramSpeed MHz   should be 3200+ if XMP enabled"
$report += "Windows          : $($os.Caption) Build $($os.BuildNumber)"

Write-Host "CPU: $($cpu.Name.Trim())" -ForegroundColor White
Write-Host "RAM: $usedRAM GB used / $totalRAM GB total @ ${ramSpeed}MHz"
Write-Host "CPU Clock: $($cpu.CurrentClockSpeed) / $($cpu.MaxClockSpeed) MHz"

# --- POWER PLAN ---------------------------------------------------------------
$report += ""
$report += Write-Section "2. POWER PLAN"

$powerOutput = powercfg /GetActiveScheme
$report += $powerOutput
Write-Host $powerOutput

# --- CPU BENCHMARK ------------------------------------------------------------
$report += ""
$report += Write-Section "3. CPU BENCHMARK (prime sieve to 500,000)"

Write-Host "Running CPU benchmark..." -ForegroundColor Yellow
$cpuStart = [System.Diagnostics.Stopwatch]::StartNew()

# Sieve of Eratosthenes - memory + CPU bound
$limit = 500000
$sieve = New-Object bool[] ($limit + 1)
for ($i = 2; $i * $i -le $limit; $i++) {
    if (-not $sieve[$i]) {
        for ($j = $i * $i; $j -le $limit; $j += $i) { $sieve[$j] = $true }
    }
}
$primeCount = ($sieve | Where-Object { $_ -eq $false }).Count - 2

$cpuStart.Stop()
$cpuMs = $cpuStart.ElapsedMilliseconds

$report += "Primes found : $primeCount (in range 2..$limit)"
$report += "Time taken   : $cpuMs ms   lower is better"
Write-Host "CPU benchmark: $cpuMs ms ($primeCount primes found)" -ForegroundColor Green

# --- MEMORY ALLOCATION BENCHMARK ---------------------------------------------
$report += ""
$report += Write-Section "4. MEMORY BENCHMARK (allocate & sum 50M integers)"

Write-Host "Running memory benchmark..." -ForegroundColor Yellow
$memStart = [System.Diagnostics.Stopwatch]::StartNew()

$arr = New-Object int[] 50000000
for ($i = 0; $i -lt $arr.Length; $i++) { $arr[$i] = $i % 256 }
$sum = [long]0
foreach ($v in $arr) { $sum += $v }

$memStart.Stop()
$memMs = $memStart.ElapsedMilliseconds
$arr = $null

$report += "Array sum  : $sum"
$report += "Time taken : $memMs ms   lower is better (sensitive to RAM speed)"
Write-Host "Memory benchmark: $memMs ms" -ForegroundColor Green

# --- DISK BENCHMARK -----------------------------------------------------------
$report += ""
$report += Write-Section "5. DISK BENCHMARK (sequential write + read 256MB)"

Write-Host "Running disk benchmark..." -ForegroundColor Yellow
$testFile = "$env:TEMP\speed_bench_$(Get-Random).tmp"
$blockSize = 1MB
$totalBytes = 512MB
$blocks = $totalBytes / $blockSize  # 512 x 1MB blocks
$buffer = New-Object byte[] $blockSize
[System.Random]::new().NextBytes($buffer)

# Write test - WriteThrough bypasses OS write cache for accurate results
$writeStart = [System.Diagnostics.Stopwatch]::StartNew()
$fs = New-Object System.IO.FileStream($testFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, $blockSize, [System.IO.FileOptions]::WriteThrough)
for ($i = 0; $i -lt $blocks; $i++) { $fs.Write($buffer, 0, $blockSize) }
$fs.Close()
$writeStart.Stop()
$writeMs = $writeStart.ElapsedMilliseconds
$writeMBs = [math]::Round(512 / ($writeMs / 1000), 1)

# Read test - SequentialScan hints OS to prefetch
$readStart = [System.Diagnostics.Stopwatch]::StartNew()
$fs = New-Object System.IO.FileStream($testFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None, $blockSize, [System.IO.FileOptions]::SequentialScan)
$readBuf = New-Object byte[] $blockSize
while ($fs.Read($readBuf, 0, $blockSize) -gt 0) {}
$fs.Close()
$readStart.Stop()
$readMs = $readStart.ElapsedMilliseconds
$readMBs = [math]::Round(512 / ($readMs / 1000), 1)

Remove-Item $testFile -Force -ErrorAction SilentlyContinue

$report += "Write: $writeMBs MB/s ($writeMs ms for 512MB)   NVMe PCIe 4.0 should be 6000+ MB/s"
$report += "Read : $readMBs MB/s ($readMs ms for 512MB)"
Write-Host "Disk write: $writeMBs MB/s | read: $readMBs MB/s" -ForegroundColor Green

# --- TOP PROCESSES ------------------------------------------------------------
$report += ""
$report += Write-Section "6. TOP 10 PROCESSES BY CPU"

$procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
$report += ($procs | Format-Table Name, @{L="CPU-sec";E={[math]::Round($_.CPU,1)}}, @{L="RAM-MB";E={[math]::Round($_.WorkingSet/1MB,0)}} -AutoSize | Out-String)

$report += Write-Section "7. TOP 10 PROCESSES BY RAM"
$procsRam = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
$report += ($procsRam | Format-Table Name, @{L="RAM-MB";E={[math]::Round($_.WorkingSet/1MB,0)}}, @{L="CPU-sec";E={[math]::Round($_.CPU,1)}} -AutoSize | Out-String)

# --- STARTUP TIME -------------------------------------------------------------
$report += Write-Section "8. LAST BOOT & STARTUP DURATION"

try {
    $bootEvent = Get-WinEvent -FilterHashtable @{LogName='System'; Id=6013} -MaxEvents 1 -ErrorAction SilentlyContinue
    $lastBoot = $os.LastBootUpTime
    $uptime   = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)

    # Boot duration from event log (Event 100 in Microsoft-Windows-Diagnostics-Performance)
    $bootPerf = Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; Id=100
    } -MaxEvents 1 -ErrorAction SilentlyContinue

    $report += "Last boot  : $([Management.ManagementDateTimeConverter]::ToDateTime($lastBoot))"
    $report += "Uptime     : $([math]::Floor($uptime.TotalHours))h $($uptime.Minutes)m"
    if ($bootPerf) {
        $bootMs = ([xml]$bootPerf.ToXml()).Event.EventData.Data | Where-Object Name -eq 'BootDuration' | Select-Object -ExpandProperty '#text'
        $report += "Boot duration: $([math]::Round([int]$bootMs/1000, 1)) seconds"
    }
} catch {
    $report += "Boot info unavailable (run as Admin for full data)"
}

# --- WINSAT QUICK SCORES ------------------------------------------------------
$report += ""
$report += Write-Section "9. WINSAT CACHED SCORES (from last assessment)"

try {
    $winsatPath = "$env:windir\Performance\WinSAT\DataStore"
    $latest = Get-ChildItem $winsatPath -Filter "*.xml" | Where-Object Name -notmatch "Initial" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        [xml]$xml = Get-Content $latest.FullName
        $scores = $xml.WinSAT.WinSPR
        $report += "Processor score  : $($scores.CpuScore)"
        $report += "Memory score     : $($scores.MemoryScore)"
        $report += "Disk score       : $($scores.DiskScore)"
        $report += "Graphics score   : $($scores.GraphicsScore)"
        $report += "(Run 'winsat formal' as Admin to refresh these)"
        Write-Host "WinSAT - CPU: $($scores.CpuScore)  RAM: $($scores.MemoryScore)  Disk: $($scores.DiskScore)  GPU: $($scores.GraphicsScore)"
    } else {
        $report += "No WinSAT data found. Run: winsat formal (takes ~5 min, run as Admin)"
    }
} catch {
    $report += "WinSAT scores unavailable: $_"
}

# --- SUMMARY ------------------------------------------------------------------
$report += ""
$report += Write-Section "SUMMARY"
$report += "CPU benchmark  : $cpuMs ms"
$report += "Memory bench   : $memMs ms"
$report += "Disk write     : $writeMBs MB/s (512MB, unbuffered)"
$report += "Disk read      : $readMBs MB/s (512MB, sequential)"
$report += "RAM speed      : $ramSpeed MHz"
$report += "CPU clock now  : $($cpu.CurrentClockSpeed) MHz / $($cpu.MaxClockSpeed) MHz max"

# --- SAVE REPORT --------------------------------------------------------------
$report | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "`nReport saved to: $outFile" -ForegroundColor Cyan
Write-Host "`nRun with 'before' label: .\benchmark.ps1 before"
Write-Host "Run with 'after' label : .\benchmark.ps1 after"
