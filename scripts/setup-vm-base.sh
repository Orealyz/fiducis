#!/bin/bash
# setup-vm-base.sh — Création des VMs de base pour FIDUCIS
# Usage : bash setup-vm-base.sh
# Prérequis : exécuter depuis le nœud Proxmox en root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/vars.env" ]]; then
    source "$SCRIPT_DIR/vars.env"
else
    echo "ERREUR : vars.env introuvable. Copier vars.env.example et l'adapter."
    exit 1
fi

PROXMOX_NODE="${PROXMOX_NODE:-pve}"
STORAGE_POOL="${STORAGE_POOL:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
VM_PASSWORD="${VM_PASSWORD:-ChangeMe123!}"

echo "=== Déploiement FIDUCIS sur le nœud $PROXMOX_NODE ==="

# -------------------------------------------------------
# Fonction : créer une VM via pvesh
# Arguments : $1=VMID $2=Nom $3=OS $4=vCPU $5=RAM(Mo) $6=Disque(Go) $7=IP $8=GW $9=VLAN
# -------------------------------------------------------
create_vm() {
    local VMID=$1
    local NAME=$2
    local OSTYPE=$3
    local CPU=$4
    local RAM=$5
    local DISK=$6
    local IP=$7
    local GW=$8
    local VLAN=$9

    echo "--- Création VM $VMID ($NAME) ---"

    pvesh create /nodes/$PROXMOX_NODE/qemu \
        --vmid $VMID \
        --name $NAME \
        --memory $RAM \
        --cores $CPU \
        --ostype $OSTYPE \
        --net0 "virtio,bridge=$BRIDGE,tag=$VLAN" \
        --scsi0 "${STORAGE_POOL}:${DISK}" \
        --ide2 "${STORAGE_POOL}:cloudinit" \
        --boot order=scsi0 \
        --serial0 socket \
        --vga serial0 \
        --ipconfig0 "ip=${IP}/24,gw=${GW}" \
        --cipassword "$VM_PASSWORD" \
        --ciuser adminmspr

    echo "VM $VMID ($NAME) créée — IP : $IP VLAN : $VLAN"
}

# -------------------------------------------------------
# Création des VMs
# VMID  Nom         OS    vCPU  RAM    Disk  IP               GW               VLAN
# -------------------------------------------------------
create_vm 200 "vm-dc"     l26  2  4096   60  "192.168.30.10"  "192.168.30.1"   30
create_vm 201 "vm-sage"   win  4  8192   60  "192.168.30.20"  "192.168.30.1"   30
create_vm 202 "vm-file"   l26  2  4096   40  "192.168.30.30"  "192.168.30.1"   30
create_vm 203 "vm-web"    l26  2  4096   40  "192.168.40.10"  "192.168.40.1"   40
create_vm 204 "vm-vpn"    l26  1  2048   20  "192.168.50.10"  "192.168.50.1"   50
create_vm 205 "vm-client" win  2  4096   60  "192.168.10.50"  "192.168.10.1"   10

# Disque données séparé pour vm-sage (Sage DB)
echo "--- Ajout disque données 100 Go sur vm-sage (201) ---"
pvesh create /nodes/$PROXMOX_NODE/qemu/201/config \
    --scsi1 "${STORAGE_POOL}:100"

# Disque données séparé pour vm-file (partages + archive audit)
echo "--- Ajout disque données 500 Go sur vm-file (202) ---"
pvesh create /nodes/$PROXMOX_NODE/qemu/202/config \
    --scsi1 "${STORAGE_POOL}:500"

# Configurer l'ordre de démarrage automatique
echo "--- Configuration démarrage automatique ---"
for VMID in 200 204 202 201 203; do
    pvesh set /nodes/$PROXMOX_NODE/qemu/$VMID/config \
        --onboot 1
done

echo ""
echo "=== Création terminée ==="
echo "Ordre de démarrage recommandé :"
echo "  vm-dc (200) → vm-vpn (204) → vm-file (202) → vm-sage (201) → vm-web (203)"
echo ""
echo "Prochaines étapes :"
echo "  1. Installer les OS via ISO (ou cloud-init pour les VMs Linux)"
echo "  2. Joindre vm-sage et vm-client au domaine AD (vm-dc)"
echo "  3. Configurer WireGuard sur vm-vpn"
echo "  4. Activer auditd sur vm-file"
