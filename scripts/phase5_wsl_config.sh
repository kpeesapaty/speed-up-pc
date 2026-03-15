#!/usr/bin/env bash
# phase5_wsl_config.sh — Configure WSL2 memory and CPU limits
# Run this FROM WITHIN WSL: bash ./scripts/phase5_wsl_config.sh

set -euo pipefail

echo "=== PHASE 5: WSL2 CONFIGURATION ==="

WSLCONFIG="/mnt/c/Users/krish/.wslconfig"

# Backup if exists
if [ -f "$WSLCONFIG" ]; then
    cp "$WSLCONFIG" "${WSLCONFIG}.bak"
    echo "Backed up existing .wslconfig to ${WSLCONFIG}.bak"
fi

# Write new config
# - memory: cap WSL at 8GB (leaves 24GB for Windows + your processes)
# - processors: give WSL 6 of your 8 cores (leaves 2 for Windows responsiveness)
# - swap: 2GB swap inside WSL
# - localhostForwarding: keep on for dev servers
# - pageReporting: off — prevents WSL from constantly reporting free pages to Windows
# - guiApplications: on (needed for any Linux GUI apps)
# - nestedVirtualization: off unless you need it (saves overhead)
cat > "$WSLCONFIG" << 'EOF'
[wsl2]
memory=8GB
processors=6
swap=2GB
pageReporting=false
localhostForwarding=true
guiApplications=true
nestedVirtualization=false

[experimental]
# Reclaim memory more aggressively when WSL is idle
autoMemoryReclaim=gradual
# Sparse VHD: disk only uses space it needs (keep this on)
sparseVhd=true
EOF

echo "Written to $WSLCONFIG:"
echo "---"
cat "$WSLCONFIG"
echo "---"

# Also tune WSL internals (applies to current session)
echo "Tuning current WSL session..."

# Drop file system caches to free memory now
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null && echo "Dropped FS caches" || echo "Could not drop caches (need sudo)"

# Reduce swappiness (less aggressive swapping)
sudo sh -c 'echo 10 > /proc/sys/vm/swappiness' 2>/dev/null && echo "Swappiness set to 10" || true

# Check current WSL memory usage
echo ""
echo "Current WSL memory usage:"
free -h

echo ""
echo "[DONE] WSL config written. RESTART WSL for changes to take effect:"
echo "  From Windows PowerShell: wsl --shutdown"
echo "  Then reopen your terminal."
