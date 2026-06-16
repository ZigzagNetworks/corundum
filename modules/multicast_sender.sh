#!/usr/bin/env bash
# sender.sh — bring up the corundum optical port as a one-way multicast SENDER (host A).
# Loads the patched mqnic driver, sets a TX-only link policy so the carrier comes
# up even though nothing is received back, assigns an IP, and routes multicast out
# the port. Idempotent: safe to run repeatedly.
#
# Usage: sudo ./multicast_sender.sh <interface>     e.g. sudo ./multicast_sender.sh enp4s0np0
set -euo pipefail

# --- must be root -----------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: this script must be run as root" 
    echo "(e.g. sudo $0 ${*:-<interface>})."
    exit 1
fi

# --- require an interface argument (use ${1:-} so set -u doesn't crash) ------
if [[ -z "${1:-}" ]]; then
    echo "ERROR: no interface specified."
    echo "Usage: sudo $0 <interface>"
    echo "e.g. sudo $0 enp4s0np0"
    exit 1
fi

### ---- config --------------------------------------------------------------
MODULE="/home/${SUDO_USER:-$USER}/Desktop/corundum_multicast/modules/mqnic/mqnic.ko"
IFACE="$1"                 # optical port wired to the OCS
### --------------------------------------------------------------------------

# --- build the module if it isn't there yet ---------------------------------
if [[ ! -e "$MODULE" ]]; then
    echo "[*] $MODULE not found — building"
    make -C "$(dirname "$MODULE")"
fi

# --- load the PATCHED driver (replace the stock auto-loaded one) -------------
if [[ -e /sys/module/mqnic/parameters/link_require_tx ]]; then
    echo "[*] patched mqnic already loaded"
else
    if lsmod | grep -q '^mqnic'; then
        echo "[*] unloading stock mqnic"
        for n in /sys/class/net/*; do
            ni=$(basename "$n")
            if ethtool -i "$ni" 2>/dev/null | grep -q '^driver: mqnic$'; then
                ip link set "$ni" down 2>/dev/null || true
            fi
        done
        rmmod mqnic
    fi
    echo "[*] inserting $MODULE"
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
    NUM=$(echo "$HOST" | grep -oP '(?<=zigzag-)\d+' || true)   # e.g. "001"
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

# --- link-up policy: TX-only (don't require RX) -----------------------------
# A sends but receives nothing back, so requiring RX would keep the carrier
# down. Gate on the always-asserted TX status instead.
echo "[*] link policy on $IFACE: TX on, RX off."
ethtool --set-priv-flags "$IFACE" link-require-rx off
ethtool --set-priv-flags "$IFACE" link-require-tx on

# --- address + bring up -----------------------------------------------------
# Broadcast to 10.0.100.255 needs no extra route: assigning $ADDR creates the
# connected route 10.0.100.0/24 dev $IFACE, which the subnet broadcast rides.
echo "[*] configuring $IFACE -> $ADDR"
ip addr replace "$ADDR" dev "$IFACE"
ip link set "$IFACE" up

echo "[*] done."
ip -br addr show "$IFACE"
echo -n "carrier: "; cat "/sys/class/net/$IFACE/carrier" 2>/dev/null || echo '?'
ethtool --show-priv-flags "$IFACE" 2>/dev/null | sed 's/^/    /'
