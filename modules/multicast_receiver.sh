#!/usr/bin/env bash
# receiver.sh — bring up the corundum optical port as a one-way multicast RECEIVER
# (hosts B/C/D). Loads the patched mqnic driver, sets a link policy that keeps the
# port usable on a one-way / power-marginal link, and assigns an IP. The receiving
# application (ffplay/socat/iperf) joins the multicast group itself.
# Idempotent: safe to run repeatedly.
#
# Usage: sudo ./receiver.sh <interface>     e.g. sudo ./receiver.sh enp1s0np0
set -euo pipefail

# --- must be root -----------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: this script must be run as root (e.g. sudo $0 ${*:-<interface>})."
    exit 1
fi

# --- require an interface argument (use ${1:-} so set -u doesn't crash) ------
if [[ -z "${1:-}" ]]; then
    echo "ERROR: no interface specified."
    echo "Usage: sudo $0 <interface>   e.g. sudo $0 enp1s0np0"
    exit 1
fi

### ---- config --------------------------------------------------------------
# Resolve paths relative to this script's location (not the cwd), so it works
# regardless of where it's invoked from. mqnic.ko is built in ./mqnic next door.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/mqnic/mqnic.ko"
IFACE="$1"          # optical port receiving from A
### --------------------------------------------------------------------------

# --- build the module if it isn't there yet ---------------------------------
if [[ ! -e "$MODULE" ]]; then
    echo "[*] $MODULE not found — building"
    make -C "$(dirname "$MODULE")"
fi

# --- load the PATCHED driver (replace the stock auto-loaded one) -------------
# Detect via /sys/module (plain file tests). Do NOT use `lsmod | grep -q`: under
# `set -o pipefail`, grep -q closes the pipe on first match so lsmod takes SIGPIPE
# and the pipeline reports failure — making the check silently miss a loaded
# module and fall through to insmod (which then fails with "File exists").
if [[ -e /sys/module/mqnic/parameters/link_require_tx ]]; then
    echo "[*] patched mqnic already loaded"
else
    if [[ -d /sys/module/mqnic ]]; then
        echo "[*] default mqnic is loaded — unloading it"
        # bring down any mqnic interface so the module isn't busy
        for n in /sys/class/net/*; do
            ni=$(basename "$n")
            drv=$(ethtool -i "$ni" 2>/dev/null | awk -F': ' '/^driver:/{print $2}' || true)
            if [[ "$drv" == mqnic ]]; then
                echo "    - bringing $ni down"
                ip link set "$ni" down 2>/dev/null || true
            fi
        done
        rmmod mqnic 2>/dev/null || modprobe -r mqnic 2>/dev/null || true
        if [[ -d /sys/module/mqnic ]]; then
            echo "ERROR: could not unload the default mqnic (module still in use)."
            echo "       Inspect users:  lsmod | grep mqnic"
            echo "       Free them (down all mqnic ifaces, stop DPDK/capture/ffmpeg) and retry."
            exit 1
        fi
    fi
    echo "[*] inserting patched $MODULE"
    insmod "$MODULE"
fi

# --- wait for the netdev to appear (udev rename can lag) ---------------------
echo "[*] waiting for $IFACE"
for _ in $(seq 1 50); do [[ -e "/sys/class/net/$IFACE" ]] && break; sleep 0.2; done
[[ -e "/sys/class/net/$IFACE" ]] || { echo "ERROR: $IFACE not found"; exit 1; }

# --- decide the address -----------------------------------------------------
# Reuse an existing global IPv4 if one is already set; otherwise derive it from
# the hostname zigzag-00N -> 10.0.100.N/24.
EXISTING_IP=$(ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null | awk '{print $4}' | head -n1)
if [[ -n "$EXISTING_IP" ]]; then
    ADDR="$EXISTING_IP"
    echo "[*] reusing existing IP on $IFACE: $ADDR"
else
    HOST=$(hostname)
    NUM=$(echo "$HOST" | grep -oP '(?<=zigzag-)\d+' || true)   # e.g. "002"
    if [[ -z "$NUM" ]]; then
        echo "ERROR: $IFACE has no IPv4 address and hostname '$HOST' is not zigzag-00N;"
        echo "       cannot auto-pick an address. Assign one manually and re-run."
        exit 1
    fi
    NUM=$((10#$NUM))                                            # base-10 (drop leading zeros)
    if [[ "$NUM" -lt 1 || "$NUM" -gt 4 ]]; then
        echo "ERROR: derived host number $NUM is outside the expected range 1-4."
        exit 1
    fi
    ADDR="10.0.100.$NUM/24"
    echo "[*] no IP on $IFACE; derived from hostname $HOST: $ADDR"
fi

# --- link-up policy ---------------------------------------------------------
# Default: don't require RX. On a one-way / power-marginal optical link the RX
# status bit may not latch even while frames arrive, so we gate on the always-on
# TX bit to keep the interface up and usable (the RX datapath delivers frames
# regardless of carrier).
#
# If your link locks RX reliably and you'd rather the carrier MEAN "light is
# present", swap the two lines below for:
#     ethtool --set-priv-flags "$IFACE" link-require-tx off
#     ethtool --set-priv-flags "$IFACE" link-require-rx on
echo "[*] link policy on $IFACE: TX off, RX on."
ethtool --set-priv-flags "$IFACE" link-require-tx off
ethtool --set-priv-flags "$IFACE" link-require-rx on

# --- address + bring up -----------------------------------------------------
echo "[*] configuring $IFACE -> $ADDR"
ip addr replace "$ADDR" dev "$IFACE"
ip link set "$IFACE" up

echo "[*] done."
ip -br addr show "$IFACE"
echo -n "carrier: "; cat "/sys/class/net/$IFACE/carrier" 2>/dev/null || echo '?'
ethtool --show-priv-flags "$IFACE" 2>/dev/null | sed 's/^/    /'
