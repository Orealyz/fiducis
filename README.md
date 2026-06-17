# FIDUCIS — Infrastructure virtualisée

> **Secteur :** Expertise comptable, juridique et conseil RH  
> **Effectif :** 35 collaborateurs — Sites : Bordeaux (siège) + La Rochelle  
> **Hyperviseur :** Proxmox VE sur matériel dédié (Bordeaux)

## Résumé du projet

FIDUCIS gère des données clients sensibles (comptabilité, paie, dossiers juridiques) sur deux sites avec du télétravail régulier. L'infrastructure actuelle souffre d'une volumétrie documentaire croissante, d'un hébergement web coûteux et d'une absence de plan de reprise. Une coupure internet d'une journée à La Rochelle a mis en lumière la fragilité du système.

L'objectif est de virtualiser les services critiques au siège de Bordeaux, d'établir une connexion sécurisée inter-sites et de réduire les coûts d'hébergement web, tout en renforçant la traçabilité des accès pour répondre aux exigences RGPD.

## VMs déployées

| VM | OS | Rôle | vCPU | RAM | Stockage |
|---|---|---|---|---|---|
| `vm-dc` | Windows Server 2022 | Active Directory + DNS | 2 | 4 Go | 60 Go |
| `vm-sage` | Windows Server 2022 | Sage Compta/Paie | 4 | 8 Go | 100 Go |
| `vm-file` | Debian 12 | Partages fichiers + audit accès | 2 | 4 Go | 500 Go |
| `vm-web` | Debian 12 | Site vitrine + espace client (Nginx) | 2 | 4 Go | 40 Go |
| `vm-vpn` | Debian 12 | WireGuard VPN (télétravail + La Rochelle) | 1 | 2 Go | 20 Go |
| `vm-client` | Windows 10 | Poste client de test | 2 | 4 Go | 60 Go |

## Accès rapide

- [Analyse des besoins](./docs/01-analyse-besoins.md)
- [Architecture & choix techniques](./docs/02-architecture.md)
- [Continuité de service](./docs/03-continuite-service.md)
- [Limites et compromis](./docs/04-limites-compromis.md)
- [Schéma architecture logique](./schemas/architecture-logique.md)
- [Schéma réseau](./schemas/reseau.md)
- [Scripts et automatisation](./scripts/README.md)

## Déploiement rapide

```bash
# 1. Cloner le dépôt sur le nœud Proxmox (Bordeaux)
git clone <url-repo> /opt/mspr-fiducis

# 2. Configurer les variables
cp scripts/vars.env.example scripts/vars.env
nano scripts/vars.env

# 3. Lancer la création des VMs de base
bash scripts/setup-vm-base.sh

# 4. Activer les snapshots automatiques
bash scripts/snapshot-backup.sh
```

> Les ajustements effectués en cours de projet sont documentés dans [docs/04-limites-compromis.md](./docs/04-limites-compromis.md).
