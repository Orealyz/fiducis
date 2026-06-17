#!/bin/bash
# snapshot-backup.sh — Snapshots automatiques des VMs FIDUCIS
# Usage : bash snapshot-backup.sh
# Planification recommandée :
#   0 2 * * * root /opt/mspr-fiducis/scripts/snapshot-backup.sh >> /var/log/snapshots-fiducis.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/vars.env" ]] && source "$SCRIPT_DIR/vars.env"

PROXMOX_NODE="${PROXMOX_NODE:-pve}"
DATE=$(date +%Y%m%d-%H%M)

# VMs critiques — snapshot quotidien (VMID:rétention_jours)
DAILY_VMS="201:14 202:14"    # vm-sage, vm-file

# VMs moins critiques — snapshot hebdomadaire
WEEKLY_VMS="200:28 203:28 204:90"  # vm-dc, vm-web, vm-vpn

echo "=== Snapshots FIDUCIS — $DATE ==="

snapshot_vm() {
    local VMID=$1
    local SNAP_NAME="auto-$DATE"
    echo "Snapshot VM $VMID : $SNAP_NAME"
    pvesh create /nodes/$PROXMOX_NODE/qemu/$VMID/snapshot \
        --snapname "$SNAP_NAME" \
        --description "Snapshot automatique $DATE" \
        --vmstate 0
    echo "Snapshot $VMID OK"
}

purge_old_snapshots() {
    local VMID=$1
    local RETENTION=$2
    echo "Purge snapshots > ${RETENTION}j pour VM $VMID"
    pvesh get /nodes/$PROXMOX_NODE/qemu/$VMID/snapshot --output-format json \
        | python3 -c "
import sys, json, subprocess
from datetime import datetime, timedelta
snaps = json.load(sys.stdin)
cutoff = datetime.now() - timedelta(days=$RETENTION)
for s in snaps:
    name = s.get('name', '')
    if not name.startswith('auto-'):
        continue
    try:
        snap_date = datetime.strptime(name, 'auto-%Y%m%d-%H%M')
        if snap_date < cutoff:
            print(f'Suppression : {name}')
            subprocess.run(['pvesh', 'delete', f'/nodes/$PROXMOX_NODE/qemu/$VMID/snapshot/{name}'], check=True)
    except ValueError:
        pass
"
}

# Snapshots quotidiens
echo "--- Snapshots quotidiens ---"
for entry in $DAILY_VMS; do
    VMID="${entry%%:*}"
    RETENTION="${entry##*:}"
    snapshot_vm "$VMID"
    purge_old_snapshots "$VMID" "$RETENTION"
done

# Snapshots hebdomadaires (lundi uniquement)
if [[ $(date +%u) -eq 1 ]]; then
    echo "--- Snapshots hebdomadaires (lundi) ---"
    for entry in $WEEKLY_VMS; do
        VMID="${entry%%:*}"
        RETENTION="${entry##*:}"
        snapshot_vm "$VMID"
        purge_old_snapshots "$VMID" "$RETENTION"
    done
else
    echo "--- Snapshots hebdomadaires ignorés (pas lundi) ---"
fi

echo "=== Terminé — $DATE ==="
