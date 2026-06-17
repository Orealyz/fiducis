# Scripts — FIDUCIS

## Vue d'ensemble

| Script | Usage |
|---|---|
| `setup-vm-base.sh` | Crée et configure les VMs via l'API Proxmox |
| `snapshot-backup.sh` | Snapshots automatiques des VMs critiques |
| `vars.env.example` | Variables à personnaliser avant lancement |

## Prérequis

- Proxmox VE 9.2-1 installé sur le nœud Bordeaux
- Accès SSH root au nœud Proxmox
- `pvesh` disponible (CLI Proxmox natif)

## Utilisation

```bash
# 1. Copier et adapter les variables
cp vars.env.example vars.env
nano vars.env

# 2. Rendre les scripts exécutables
chmod +x setup-vm-base.sh snapshot-backup.sh

# 3. Créer les VMs
bash setup-vm-base.sh

# 4. Tester le snapshot manuellement
bash snapshot-backup.sh

# 5. Automatiser via cron
echo "0 2 * * * root /opt/mspr-fiducis/scripts/snapshot-backup.sh >> /var/log/snapshots-fiducis.log 2>&1" \
  > /etc/cron.d/proxmox-snapshots-fiducis
```

## Adaptation à un autre client

Pour réutiliser sur un autre contexte :

1. Copier le dossier `scripts/`
2. Modifier `vars.env` (nœud, stockage, bridge, IPs)
3. Ajuster les VMIDs si des VMs existent déjà sur le nœud
4. Adapter la rétention des snapshots selon les exigences métier

Les scripts sont commentés et paramétrables via `vars.env` uniquement — aucune valeur n'est codée en dur dans le script principal.

## Note sur la sécurité

- Le fichier `vars.env` contient des mots de passe : **ne pas committer dans Git** (ajouté au `.gitignore`)
- Les clés WireGuard doivent être générées manuellement (`wg genkey`) et ne doivent jamais apparaître dans le dépôt
