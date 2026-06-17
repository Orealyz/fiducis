# 01 — Analyse des besoins — FIDUCIS

## Situation existante

FIDUCIS est un cabinet de 35 collaborateurs répartis sur deux sites (Bordeaux et La Rochelle) avec du télétravail régulier (2 jours par semaine). Les données traitées sont sensibles : dossiers comptables, pièces justificatives clients, éléments de paie, conseils juridiques.

L'infrastructure repose sur un Windows Server local à Bordeaux (Active Directory, Sage, partages fichiers) et un hébergement web externe coûteux. Aucun plan de reprise n'est formalisé.

### Problèmes identifiés

| Problème | Impact opérationnel |
|---|---|
| Explosion de la volumétrie documentaire | Saturation des partages, lenteurs sur les scans |
| Hébergement web externe coûteux | Coût récurrent élevé pour le site vitrine et l'espace client |
| Pression RGPD | Aucune traçabilité des accès aux dossiers clients |
| Coupure internet La Rochelle (1 journée) | Site entier paralysé, pas de plan de secours |
| Aucun plan de reprise | En cas de panne serveur, durée de remise en service inconnue |
| Télétravail non sécurisé | Accès distants via des solutions non maîtrisées |

### Besoins exprimés

- Réduction des coûts d'hébergement web
- Traçabilité des accès aux dossiers (qui a accédé à quoi, quand)
- Continuité de service en cas de coupure internet sur un site
- Sécurisation des accès distants (télétravail, La Rochelle)
- Conformité RGPD : données clients hébergées en maîtrise

## Reformulation en exigences techniques

### Exigences fonctionnelles

1. **Active Directory** : maintien et virtualisation du contrôleur de domaine existant, qui centralise l'authentification des 35 collaborateurs
2. **Sage** : virtualisation sur une VM Windows dédiée, accessible depuis Bordeaux et via VPN depuis La Rochelle et les télétravailleurs
3. **Partages fichiers avec audit** : serveur de fichiers Linux avec journalisation des accès (audit POSIX + logs centralisés)
4. **Espace client web** : auto-hébergement du site vitrine + espace de dépôt de pièces, remplacement du prestataire web externe
5. **VPN inter-sites** : tunnel WireGuard permanent entre Bordeaux et La Rochelle + accès télétravail

### Exigences RGPD et sécurité

1. Journalisation des accès aux dossiers clients (qui, quand, quel fichier)
2. Données hébergées sur le territoire national (serveur on-premise Bordeaux)
3. Accès distants uniquement via VPN chiffré
4. Pas d'accès direct RDP exposé sur internet
5. Politique de mots de passe et durée de session gérées par AD

### Exigences de continuité

1. Snapshots quotidiens des VMs critiques (vm-dc, vm-sage, vm-file)
2. Procédure de reprise documentée et testée
3. En cas de coupure internet La Rochelle : accès local aux fichiers partagés sur un NAS local (hors périmètre VM, recommandation complémentaire)

### Justification de la virtualisation

- **Consolidation** : le serveur Windows Server existant devient une VM, aux côtés de Sage et du serveur de fichiers — un seul hôte physique à maintenir
- **Isolation de Sage** : une mise à jour de Sage ou un bug n'affecte pas le contrôleur AD
- **Espace client auto-hébergé** : une VM Debian avec Nginx peut remplacer l'hébergement externe mutualisé, pour un coût marginal (électricité du serveur Proxmox)
- **Traçabilité** : les logs d'accès Linux (auditd) sont plus fins et centralisables que les partages Windows natifs sans licence premium
- **VPN intégré** : une VM légère WireGuard remplace une solution VPN commerciale

## Logiciels et usages retenus

| Domaine | Outil | VM associée |
|---|---|---|
| Identité | Active Directory | `vm-dc` |
| Compta / paie | Sage (Windows) | `vm-sage` |
| Partages + audit | Samba + auditd (Linux) | `vm-file` |
| Site vitrine + espace client | Nginx + app dédiée | `vm-web` |
| VPN | WireGuard | `vm-vpn` |
| Collaboration | Microsoft 365 (cloud, inchangé) | — |
| Téléphonie VoIP | Inchangé (softphone existant) | — |
