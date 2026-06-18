#!/usr/bin/env bash
# multicast_revert.sh — undo the multicast setup and return mqnic to its default
# state. For every corundum (mqnic) port it flushes addresses and brings the link
# down, then unloads the (patched) driver and reloads the STOCK module from
# /lib/modules — which restores the default link policy (carrier up requires BOTH
# TX and RX) and drops the per-port link-require-* flags entirely.
#
# Host-wide and idempotent. Does NOT delete your patched build.
#
# Usage: sudo ./multicast_revert.sh
set -uo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: this script must be run as root (e.g. sudo $0)."
    exit 1
fi

# --- find corundum interfaces and clear their config ------------------------
echo "[*] clearing corundum (mqnic) interfaces"
found=0
for n in /sys/class/net/*; do
    ni=$(basename "$n")
    if ethtool -i "$ni" 2>/dev/null | grep -q '^driver: mqnic$'; then
        found=1
        echo "    - $ni: flush addresses + link down"
        ip addr flush dev "$ni" 2>/dev/null || true   # also drops the connected route
        ip link set "$ni" down 2>/dev/null || true
    fi
done
[[ "$found" -eq 1 ]] || echo "    (no mqnic interfaces currently present)"

# --- unload whatever mqnic is loaded ----------------------------------------
# Detect via /sys/module, not `lsmod | grep -q` (pipefail + grep -q closing the
# pipe makes lsmod take SIGPIPE and the check falsely report "not loaded").
if [[ -d /sys/module/mqnic ]]; then
    echo "[*] removing loaded mqnic module"
    rmmod mqnic 2>/dev/null || modprobe -r mqnic 2>/dev/null || true
    if [[ -d /sys/module/mqnic ]]; then
        echo "ERROR: rmmod failed (module in use?). Stop any users of the NIC"
        echo "       (DPDK/vfio bindings, capture tools) and re-run."
        exit 1
    fi
fi

# --- load the stock driver from /lib/modules --------------------------------
echo "[*] loading stock mqnic (modprobe)"
if modprobe mqnic 2>/dev/null; then
    echo "[*] stock mqnic loaded"
else
    echo "WARNING: 'modprobe mqnic' failed — no installed stock module was found."
    echo "         Your patched build is untouched; load it with:"
    echo "           sudo insmod /home/${SUDO_USER:-$USER}/Desktop/corundum_multicast/modules/mqnic/mqnic.ko"
fi

# --- report -----------------------------------------------------------------
echo "[*] state now:"
if [[ -e /sys/module/mqnic/parameters/link_require_tx ]]; then
    echo "    NOTE: a PATCHED driver is loaded (link_require_* still present)."
    echo "          A stock module isn't installed in /lib/modules, so default"
    echo "          behavior is restored only if you avoid setting the flags."
else
    echo "    stock driver loaded — no per-port link flags; default behavior restored."
fi
echo "    parameters:"
ls /sys/module/mqnic/parameters/ 2>/dev/null | sed 's/^/      /' || echo "      (mqnic not loaded)"
