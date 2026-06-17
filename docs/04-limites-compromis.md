# 04 — Limites et compromis — FIDUCIS

## Limites liées à l'environnement local

### Nœud unique

Un seul hôte Proxmox à Bordeaux. Si ce serveur tombe en panne matérielle, tous les services sont interrompus simultanément. FIDUCIS opérant dans un secteur à contraintes légales, cette limite est importante à signaler au client. En production réelle, un cluster 2 nœuds est indispensable.

### Site La Rochelle sans serveur local

Le site de La Rochelle dépend entièrement de la connexion internet pour accéder aux services Bordeaux (Sage, partages, AD). La coupure récente d'une journée illustre ce risque. La résolution complète nécessiterait un serveur local à La Rochelle (réplication AD, cache de fichiers), hors périmètre de ce projet.

### Sage : licence et compatibilité

Sage est un logiciel Windows avec un système de licences parfois capricieux en environnement virtualisé (activation matérielle). Il faudra vérifier la compatibilité de la licence actuelle avec une VM Proxmox/KVM avant migration. Ce point doit être clarifié avec l'éditeur ou le prestataire Sage.

### Espace client web simplifié

L'espace client (dépôt de pièces, prise de RDV) est implémenté de façon simple (formulaires + stockage local). Une solution dédiée (e.g. portail client Sage, application métier) serait plus adaptée à long terme mais dépasse le cadre de ce projet.

## Compromis techniques réalisés

| Compromis | Raison | Alternative en contexte réel |
|---|---|---|
| Un seul nœud Proxmox | Contrainte matérielle | Cluster 2 nœuds Proxmox avec HA |
| Pas de réplication La Rochelle | Budget et complexité | Réplication Proxmox ou serveur secondaire |
| Sauvegarde cloud optionnelle | Budget | Proxmox Backup Server + stockage objet chiffré |
| Pas de supervision temps réel | Hors périmètre MSPR | Zabbix ou Grafana/Prometheus |
| vm-web en auto-hébergement simple | Remplacement progressif du prestataire | Solution managée (éventuellement plus tard) |
| Logs auditd locaux (non centralisés) | Simplicité | SIEM (Wazuh, Graylog) pour centralisation |

## Ce que l'on ferait différemment en production réelle

1. **Cluster Proxmox 2 nœuds** à Bordeaux, avec migration automatique des VMs en cas de panne d'un nœud

2. **Proxmox Backup Server** sur NAS dédié avec chiffrement AES-256 et envoi vers stockage cloud

3. **Serveur secondaire La Rochelle** : réplication de l'AD (contrôleur de domaine secondaire) et cache de fichiers pour fonctionnement autonome en cas de coupure internet

4. **Firewall UTM** (OPNsense) en VM dédiée ou boîtier physique : filtrage inter-VLAN, IDS/IPS, logs de connexions

5. **SIEM léger** (Wazuh open-source) : centralisation des logs auditd, alertes en temps réel sur accès suspects, tableau de bord pour les contrôles RGPD

6. **Double authentification (MFA)** pour les accès VPN et Sage (surtout pour les télétravailleurs)

7. **Chiffrement des disques VMs** contenant des données clients (Proxmox supporte le chiffrement via LUKS)

8. **Contrat de maintenance** avec un prestataire pour garantir un RTO (Recovery Time Objective) inférieur à 4 heures

## Évolutions envisagées

- **Court terme** : mettre en place les exports Sage automatiques et les tester
- **Moyen terme** : déployer un serveur secondaire à La Rochelle (contrôleur AD + NAS local)
- **Long terme** : migration de l'espace client vers une solution métier dédiée (portail intégré Sage ou solution SaaS spécialisée cabinet comptable)
