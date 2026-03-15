#!/usr/bin/env bash
# phase7_terminal_wsl_perf.sh — Diagnose and fix terminal/shell input lag
# Run FROM WITHIN WSL: bash ./scripts/phase7_terminal_wsl_perf.sh

set -euo pipefail

echo "=== PHASE 7: TERMINAL & SHELL PERFORMANCE ==="

# ─── MEASURE SHELL STARTUP TIME ───────────────────────────────────────────────
echo ""
echo "[Shell startup time]"
echo "Measuring zsh startup (run 5 times for average)..."

total=0
for i in {1..5}; do
    t=$( { time zsh -i -c exit; } 2>&1 | grep real | awk '{print $2}')
    echo "  Run $i: $t"
done

echo ""
echo "Profiling which part of your .zshrc is slow:"
echo "  (uncomment 'zprof' lines below to see per-plugin timings)"

# Check if zprof is available
if zsh -c 'zmodload zsh/zprof 2>/dev/null && echo ok' | grep -q ok; then
    echo ""
    echo "Run this for a detailed breakdown:"
    echo "  zsh -i -c 'zmodload zsh/zprof; zprof' 2>&1 | head -40"
fi

# ─── CHECK OH-MY-ZSH / PLUGIN LOAD ───────────────────────────────────────────
echo ""
echo "[Checking shell framework]"
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh detected."
    plugin_count=$(grep -oP "plugins=\(\K[^)]*" ~/.zshrc 2>/dev/null | wc -w || echo "?")
    echo "  Active plugins: ~$plugin_count"
    echo ""
    echo "  Slow OMZ plugins to disable if present (edit ~/.zshrc):"
    echo "    - nvm          (adds 200-500ms — use lazy load instead)"
    echo "    - rbenv/pyenv  (adds 100-300ms — use lazy load)"
    echo "    - aws          (can be slow)"
    echo "    - kubectl      (adds 100ms+)"
    echo ""
    echo "  Fast alternative: consider 'zinit' or 'sheldon' for lazy plugin loading"
elif [ -f "$HOME/.zshrc" ] && grep -q "starship\|p10k\|powerlevel" "$HOME/.zshrc" 2>/dev/null; then
    echo "Custom prompt (Starship/Powerlevel10k) detected."
fi

# ─── CHECK POWERLEVEL10K CONFIG ───────────────────────────────────────────────
if [ -f "$HOME/.p10k.zsh" ]; then
    echo ""
    echo "[Powerlevel10k detected]"
    echo "  P10k should be fast — but verify 'instant prompt' is enabled:"
    if grep -q "POWERLEVEL9K_INSTANT_PROMPT" "$HOME/.zshrc" 2>/dev/null; then
        echo "  Instant prompt: configured"
    else
        echo "  WARNING: instant prompt not found in .zshrc — add this at TOP of .zshrc:"
        echo "    if [[ -r \"\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\" ]]; then"
        echo "      source \"\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\""
        echo "    fi"
    fi
fi

# ─── WSL INTEROP OVERHEAD ─────────────────────────────────────────────────────
echo ""
echo "[WSL ↔ Windows interop overhead]"
echo "Testing 'ls' on a Windows path vs native Linux path:"

# Time Windows path access
wt=$( { time ls /mnt/c/Users/krish > /dev/null; } 2>&1 | grep real | awk '{print $2}')
# Time native Linux path access
lt=$( { time ls "$HOME" > /dev/null; } 2>&1 | grep real | awk '{print $2}')

echo "  Windows path (/mnt/c/...): $wt"
echo "  Linux path   (~/)        : $lt"
echo ""
echo "  Tip: Keep project files in WSL filesystem (~/) not on /mnt/c/ for speed."
echo "  Accessing Windows filesystem from WSL (and vice versa) has 10-50x overhead."

# ─── CHECK IF PROJECTS ARE ON WINDOWS VS LINUX FS ────────────────────────────
echo ""
echo "[Project filesystem location check]"
if [ -d "/mnt/c/Users/krish/projects" ] && [ -d "$HOME/projects" ]; then
    echo "  You have projects in BOTH locations."
    echo "  For WSL dev work, prefer ~/projects (Linux fs) over /mnt/c/Users/krish/projects"
elif [ -d "/mnt/c/Users/krish/projects" ]; then
    echo "  WARNING: Your projects appear to be on the Windows filesystem (/mnt/c/)"
    echo "  Consider moving active WSL projects to ~/projects for significantly faster file I/O"
fi

# ─── WINDOWS TERMINAL SETTINGS HINT ─────────────────────────────────────────
echo ""
echo "[Windows Terminal performance tips]"
echo "  In Windows Terminal settings.json, ensure:"
echo "    - 'useAcrylic': false (blur effects cost GPU cycles at 4K)"
echo "    - 'experimental.rendering.software': false (GPU rendering should be on)"
echo "    - 'antialiasingMode': 'cleartype' (faster than 'grayscale')"
echo ""
echo "  Settings file location:"
echo "    /mnt/c/Users/krish/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"

# ─── BENCHMARK WSL SHELL RESPONSIVENESS ──────────────────────────────────────
echo ""
echo "[WSL shell responsiveness test]"
echo "Timing 1000 simple echo operations..."
start=$(date +%s%N)
for i in $(seq 1 1000); do echo -n "" ; done
end=$(date +%s%N)
elapsed=$(( (end - start) / 1000000 ))
echo "  1000 echo ops: ${elapsed}ms (target: <100ms)"

echo ""
echo "[DONE] Terminal/WSL diagnostics complete."
echo "Key action: run your shell startup time with 'time zsh -i -c exit'"
echo "If >300ms, share the result and we'll tune your .zshrc"
