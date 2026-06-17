# 03 — Continuité de service — FIDUCIS

## Contexte

FIDUCIS opère dans un secteur où les données sont sensibles et les délais contraints (clôtures fiscales, dépôts de bilans). Une interruption de service peut avoir des conséquences légales pour les clients du cabinet. La coupure d'une journée à La Rochelle a révélé l'absence totale de plan de reprise.

## Stratégie de sauvegarde

### Règle 3-2-1 adaptée

| Règle | Application chez FIDUCIS |
|---|---|
| **3** copies | Données live Proxmox + snapshot Proxmox + export externe |
| **2** supports | SSD interne Proxmox + NAS dédié sauvegarde (réseau local) |
| **1** hors site | Copie chiffrée mensuelle vers un stockage cloud (Backblaze B2 ou OVH Object Storage) |

> Le chiffrement des sauvegardes cloud est obligatoire compte tenu de la sensibilité des données (RGPD).

### Planification des snapshots

| VM | Fréquence | Rétention | Justification |
|---|---|---|---|
| vm-dc | Hebdomadaire | 4 semaines | Changements AD rares |
| vm-sage | Quotidienne | 14 jours | Données compta/paie critiques |
| vm-file | Quotidienne | 14 jours | Dossiers clients actifs |
| vm-web | Hebdomadaire | 4 semaines | Contenu moins critique |
| vm-vpn | Mensuel | 3 mois | Configuration stable |

> La rétention de 14 jours pour vm-sage et vm-file dépasse le minimum (7 jours) pour couvrir les erreurs découvertes tardivement (ex. : mauvaise saisie en paie détectée après le virement).

### Sauvegarde applicative Sage

Sage dispose de sa propre fonction d'export. En complément des snapshots VM :

```bash
# Export Sage — à adapter selon la version installée
# À exécuter quotidiennement via planificateur Windows
# Chemin exemple : C:\Sage\Exports\
# Copié vers vm-file > /srv/samba/backups/sage/ via script PowerShell
```

### Audit et traçabilité (RGPD)

La traçabilité des accès est gérée par `auditd` sur vm-file :

```bash
# Configuration auditd — règles d'audit sur les dossiers clients
# /etc/audit/rules.d/fiducis.rules

# Surveiller tous les accès en lecture/écriture sur les dossiers clients
-a always,exit -F dir=/srv/samba/clients/ -F perm=rwxa -k acces_clients

# Surveiller les suppressions de fichiers
-a always,exit -F dir=/srv/samba/clients/ -F perm=wa -k modifications_clients
```

Les logs sont conservés dans `/var/log/audit/` et archivés mensuellement. Rotation sur 13 mois.

## Points de défaillance identifiés

| Point de défaillance | Impact | Mitigation |
|---|---|---|
| Panne hôte Proxmox | Tous les services hors ligne | Snapshot + procédure redémarrage rapide |
| Corruption vm-sage | Sage inaccessible, paie bloquée | Snapshot quotidien, restauration < 30 min |
| Coupure internet Bordeaux | VPN télétravail + La Rochelle coupés | Hors périmètre VM ; connexion 4G de secours recommandée |
| Coupure internet La Rochelle | Accès aux serveurs Bordeaux impossible | NAS local La Rochelle en mode dégradé (hors périmètre VM) |
| Saturation vm-file | Partages inaccessibles | Alertes Proxmox sur espace disque, volume séparé |
| Fuite de données | Conséquences RGPD graves | Accès VPN uniquement, audit activé, chiffrement cloud |

## Scénarios d'incident et procédures de reprise

### Scénario 1 — Sage inaccessible (cas le plus impactant)

**Symptôme :** Impossible de se connecter à Sage, paie du mois bloquée.

**Procédure :**

```
1. Se connecter à Proxmox (https://proxmox-bordeaux:8006)
2. Vérifier l'état de vm-sage : est-elle démarrée ?
3. Si arrêtée : démarrer vm-sage, attendre 3 min, retester
4. Si corrompue :
   a. Arrêter vm-sage
   b. Aller dans Snapshots > sélectionner dernier snapshot quotidien
   c. Cliquer Rollback
   d. Démarrer vm-sage
   e. Vérifier l'accès Sage depuis un poste client
5. Informer les utilisateurs de la perte de saisies depuis le dernier snapshot
6. Consigner l'incident dans le journal des incidents
```

**Temps de restauration estimé : 20 à 40 minutes**

---

### Scénario 2 — Coupure internet La Rochelle

**Symptôme :** Les collaborateurs de La Rochelle ne peuvent plus accéder aux partages ni à Sage.

**Procédure en mode dégradé :**

```
1. Vérifier si la coupure est totale (appel téléphonique au site)
2. Si coupure partielle : relancer le routeur La Rochelle
3. Si coupure totale (FAI) :
   a. Activer la connexion 4G de secours (si disponible)
   b. Le tunnel WireGuard se reconnecte automatiquement
4. Si aucune connexion possible :
   a. Les collaborateurs travaillent en local sur les fichiers synchronisés (OneDrive)
   b. Sage : travail en local impossible sans accès serveur
      → reporter les saisies urgentes au retour de connexion
5. Durée max acceptable sans connexion : 4 heures (demi-journée)
```

**Note :** un NAS local à La Rochelle avec synchronisation différée serait la solution idéale mais est hors périmètre de ce projet.

---

### Scénario 3 — Demande RGPD : qui a accédé au dossier du client X ?

**Procédure :**

```bash
# Sur vm-file, consulter les logs auditd
# Recherche par nom de dossier client
ausearch -k acces_clients --start today | grep "client-dupont"

# Ou sur une période donnée
ausearch -k acces_clients --start 2025-01-01 --end 2025-01-31 \
  | aureport --file -i | grep "dupont"

# Export pour traçabilité (format texte)
ausearch -k acces_clients --start 2025-01-01 \
  > /var/log/audit/export-rgpd-dupont.txt
```

Ce rapport peut être fourni lors d'un contrôle CNIL ou à la demande d'un client.

## Configuration recommandée dans Proxmox

```
# Ordre de démarrage des VMs
vm-dc   : ordre 1, délai 60s  (AD requis en premier)
vm-vpn  : ordre 2, délai 30s  (VPN disponible tôt)
vm-file : ordre 3, délai 30s
vm-sage : ordre 4, délai 30s
vm-web  : ordre 5, délai 0s
```

## Tests de restauration

Tests mensuels obligatoires :

- Restaurer vm-sage depuis un snapshot sur une VM temporaire
- Vérifier l'accès Sage et l'intégrité des données
- Tester la reconnexion VPN La Rochelle après redémarrage vm-vpn
- Vérifier la présence et la lisibilité des logs auditd sur la période
- Consigner les résultats dans `tests-restauration.md`
