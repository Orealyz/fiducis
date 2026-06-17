# Schéma — Architecture logique FIDUCIS

## Diagramme (Mermaid)

```mermaid
graph TD
    subgraph Bordeaux["Site Bordeaux — Hôte Proxmox VE"]
        subgraph VLAN30["VLAN 30 — Serveurs (192.168.30.0/24)"]
            DC["vm-dc\nWindows Server 2022\nActive Directory + DNS\n192.168.30.10"]
            SAGE["vm-sage\nWindows Server 2022\nSage Compta/Paie\n192.168.30.20"]
            FILE["vm-file\nDebian 12\nSamba + auditd\n192.168.30.30"]
        end

        subgraph VLAN40["VLAN 40 — DMZ (192.168.40.0/24)"]
            WEB["vm-web\nDebian 12\nNginx + Espace client\n192.168.40.10"]
        end

        subgraph VLAN50["VLAN 50 — VPN (192.168.50.0/24)"]
            VPN["vm-vpn\nDebian 12\nWireGuard\n192.168.50.10"]
        end

        subgraph VLAN10["VLAN 10 — Postes (192.168.10.0/24)"]
            CLIENT["vm-client\nWindows 10 test\n192.168.10.50"]
            POSTES["Postes Bordeaux\n192.168.10.x"]
        end
    end

    subgraph LaRochelle["Site La Rochelle"]
        LR_PC["Postes La Rochelle\n10.10.0.x"]
        LR_GW["Routeur WG\n(tunnel permanent)"]
    end

    subgraph Distants["Accès distants"]
        TW["Télétravailleurs\n(client WireGuard)"]
        CLIENTS_WEB["Clients web\n(Internet)"]
    end

    DC -- "AD Auth" --> CLIENT
    DC -- "AD Auth" --> POSTES
    DC -- "DNS" --> SAGE
    FILE -- "Samba" --> CLIENT
    FILE -- "Samba" --> POSTES
    SAGE -- "RDP/App" --> POSTES

    TW -- "WireGuard chiffré" --> VPN
    LR_GW -- "Tunnel permanent" --> VPN
    VPN -- "Accès interne" --> FILE
    VPN -- "Accès interne" --> SAGE
    VPN -- "Accès interne" --> DC

    LR_PC --> LR_GW

    CLIENTS_WEB -- "HTTPS 443" --> WEB
```

## Représentation textuelle

```
SITE BORDEAUX
┌──────────────────────────────────────────────────────────────┐
│                     Hôte Proxmox VE                          │
│                                                              │
│  VLAN 30 — Serveurs                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   vm-dc      │  │  vm-sage     │  │  vm-file     │       │
│  │ Win Srv 2022 │  │ Win Srv 2022 │  │  Debian 12   │       │
│  │ AD + DNS     │  │ Sage C/Paie  │  │ Samba+auditd │       │
│  │ .30.10       │  │ .30.20       │  │ .30.30       │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  VLAN 40 — DMZ          VLAN 50 — VPN                       │
│  ┌──────────────┐       ┌──────────────┐                     │
│  │   vm-web     │       │   vm-vpn     │                     │
│  │  Debian 12   │       │  Debian 12   │                     │
│  │ Nginx+Espace │       │  WireGuard   │                     │
│  │ .40.10       │       │ .50.10       │                     │
│  └──────────────┘       └──────────────┘                     │
│                               │                              │
│  VLAN 10 — Postes Bordeaux    │                              │
│  Postes (192.168.10.x)        │                              │
│  vm-client (.10.50)           │                              │
└──────────────────────────────────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────────────┐  ┌─────────────┐  ┌───────────┐
    │ Site La Rochelle│  │Télétravaill.│  │Clients web│
    │ Routeur WG      │  │Client WG    │  │Internet   │
    │ 10.10.0.0/24    │  │10.20.0.0/24 │  │→ vm-web   │
    │ Postes: 10.10.x │  │             │  │           │
    └─────────────────┘  └─────────────┘  └───────────┘
```

## Flux de données sensibles (RGPD)

```
Collaborateur télétravail
        │
        │ WireGuard (chiffré)
        ▼
    vm-vpn (50.10)
        │
        │ VLAN interne
        ▼
    vm-file (30.30)  ←── auditd journalise chaque accès
        │
        │ Partage Samba
        ▼
    /srv/samba/clients/[nom-client]/
        │
        │ Snapshot quotidien
        ▼
    Proxmox Backup → NAS local → Cloud chiffré
```
