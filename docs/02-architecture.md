# 02 — Architecture — FIDUCIS

## Choix de l'hyperviseur

### Comparaison VirtualBox vs Proxmox VE

| Critère | VirtualBox | Proxmox VE |
|---|---|---|
| Type | Type 2 (s'installe sur un OS hôte) | Type 1 (bare-metal) |
| Stabilité 24/7 | Limitée (dépend de l'OS hôte) | Bonne (noyau Linux minimaliste) |
| Gestion multi-VMs | Manuelle, GUI lourde | Interface web centralisée |
| Snapshots planifiés | Non (manuel uniquement) | Oui (planificateur intégré) |
| VLAN / réseau avancé | Limité | Linux Bridge VLAN-aware |
| Licence | Gratuit | Gratuit (sans abonnement support) |

### Choix retenu : Proxmox VE

FIDUCIS a des impératifs de disponibilité liés aux délais fiscaux et aux obligations clients. Le serveur doit tourner en continu. Proxmox VE, installé en bare-metal, offre une stabilité bien supérieure à VirtualBox et intègre nativement la gestion des sauvegardes et du réseau virtualisé.

> **Compromis notable :** un seul nœud Proxmox est déployé (contrainte matérielle). En production, un cluster 2 nœuds avec Proxmox Backup Server serait la cible.

## Architecture logique

### Machines virtuelles

```
Proxmox VE — Bordeaux (hôte physique)
├── vm-dc      — Windows Server 2022  — Active Directory + DNS
├── vm-sage    — Windows Server 2022  — Sage Compta/Paie (10 utilisateurs simultanés)
├── vm-file    — Debian 12            — Partages Samba + audit accès (auditd)
├── vm-web     — Debian 12            — Site vitrine + espace client (Nginx)
├── vm-vpn     — Debian 12            — WireGuard VPN (télétravail + La Rochelle)
└── vm-client  — Windows 10           — Poste client de test
```

### Rôles et justifications

**vm-dc** — Active Directory  
Virtualisation du contrôleur de domaine existant. Gère l'authentification de tous les collaborateurs (Bordeaux, La Rochelle via VPN, télétravailleurs). DNS interne pour la résolution des noms de VMs.

**vm-sage** — Sage Compta/Paie  
Sage nécessite Windows. VM dédiée avec 4 vCPU et 8 Go RAM pour supporter 10 connexions simultanées. Isolation totale : un problème sur Sage ne touche pas l'AD ni les partages.

**vm-file** — Partages + audit  
Samba expose les partages aux postes clients via AD (authentification transparente). `auditd` est configuré pour journaliser chaque accès aux dossiers clients (qui, quand, quelle action). Les logs sont conservés 1 an (exigence RGPD recommandée).

**vm-web** — Site vitrine + espace client  
Nginx sert le site vitrine WordPress et une application d'espace client (dépôt de pièces, prise de rendez-vous). Remplace l'hébergement externe coûteux. VM en DMZ, isolée du reste.

**vm-vpn** — WireGuard VPN  
Point d'entrée unique pour tous les accès distants. Deux profils : télétravailleurs (accès vm-file, vm-sage via AD) et tunnel permanent vers le site de La Rochelle.

**vm-client** — Poste de test  
Valide les accès Samba, l'authentification AD, la connexion Sage et les logs d'audit.

## Réseau virtualisé

### VLANs

| VLAN | Nom | Usage |
|---|---|---|
| 10 | Postes | Postes Bordeaux |
| 30 | Serveurs | VMs Proxmox (DC, Sage, File) |
| 40 | DMZ | vm-web (exposition publique) |
| 50 | VPN | vm-vpn (accès distants) |
| 99 | Management | Interface Proxmox |

### Adressage IP

| VM | IP fixe | VLAN |
|---|---|---|
| vm-dc | 192.168.30.10 | 30 |
| vm-sage | 192.168.30.20 | 30 |
| vm-file | 192.168.30.30 | 30 |
| vm-web | 192.168.40.10 | 40 |
| vm-vpn | 192.168.50.10 | 50 |
| vm-client | 192.168.10.50 | 10 |

| Site | Réseau | Connexion |
|---|---|---|
| Bordeaux — Postes | 192.168.10.0/24 | Local |
| Bordeaux — Serveurs | 192.168.30.0/24 | Local |
| La Rochelle | 10.10.0.0/24 | WireGuard tunnel vers vm-vpn |
| Télétravailleurs | 10.20.0.0/24 | WireGuard client-to-site |

### Accès distants

- **Télétravailleurs** : client WireGuard sur le laptop → vm-vpn → accès vm-file et vm-sage (via AD)
- **Site La Rochelle** : tunnel WireGuard permanent entre un routeur/PC La Rochelle et vm-vpn → accès transparent aux partages Bordeaux
- **Aucun RDP exposé sur internet** : tout passe par le VPN

## Estimation des ressources

| VM | vCPU | RAM | Disque OS | Disque données |
|---|---|---|---|---|
| vm-dc | 2 | 4 Go | 60 Go | — |
| vm-sage | 4 | 8 Go | 60 Go | 100 Go |
| vm-file | 2 | 4 Go | 40 Go | 500 Go |
| vm-web | 2 | 4 Go | 40 Go | — |
| vm-vpn | 1 | 2 Go | 20 Go | — |
| vm-client | 2 | 4 Go | 60 Go | — |
| **Total** | **13** | **26 Go** | **280 Go** | **600 Go** |

### Matériel cible

| Ressource | Minimum | Recommandé |
|---|---|---|
| CPU | 8 cœurs | 12 cœurs |
| RAM | 32 Go | 64 Go |
| Stockage OS | 120 Go SSD | 240 Go SSD |
| Stockage données | 1 To | 2 To |
