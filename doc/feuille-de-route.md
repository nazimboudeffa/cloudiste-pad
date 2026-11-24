# Feuille de route — Libre Cloud Gaming (`cloudiste-pad`)

> Dernière mise à jour : 2026-11-24 · Légende : ✅ livré · 🚧 en cours · ⬜ prévu · 💡 exploration

## Vision

Rester la plus petite plateforme de cloud gaming **autonome** possible : un seul script lancé sur une VM GPU louée, Moonlight côté client, aucune base de données, aucun compte, aucun service à héberger. Chaque évolution doit pouvoir être utilisée par une seule personne en quelques minutes, sans infrastructure intermédiaire.

## Principes directeurs (garde-fous)

1. **Un seul point d'entrée** : `deploy.sh` reste le seul outil nécessaire ; pas de CLI à installer côté client.
2. **Pas de serveur à maintenir** : pas de backend, pas de BDD, pas d'UI web hébergée.
3. **Sécurité par défaut** : identifiants générés localement, accès privé recommandé (Tailscale), aucun secret dans le dépôt.
4. **Coût maîtrisé** : le script ne gère pas la facturation de la VM ; l'utilisateur garde la main sur le provider.
5. **Usage personnel, une session** : on ne transforme pas le projet en service multi-joueurs par accident.
6. **Conformité AGPL** : toute modification distribuée reste source ouverte ; l'image amont est pinée et citée.
7. **Documentation exécutable** : toute nouvelle commande est documentée dans le README le jour même.

## État actuel — v0.1 « MVP déployable » ✅/🚧

Déjà en place :

- `deploy.sh` : détection GPU, installation Docker + NVIDIA Container Toolkit, génération de `.env`,
  `docker compose`, image `ghcr.io/pierrebeucher/cloudypad/sunshine:0.46.0`, commandes
  `deploy / start / stop / restart / status / logs / csrf / destroy / purge / help`.
- README complet : choix du fournisseur, GPU, ports, pairing Moonlight, dépannage, limites.
- `doc/vast-ai.md` : tutoriel pas-à-pas (clé SSH, VM Ubuntu, ports aléatoires, Tailscale).
- Licence AGPL-3.0 et avertissements RunPod / Clore.ai (pas de Docker Compose ni de UDP).

En cours / dette immédiate :

- 🚧 Correctifs non commités : précisions Tailscale/CSRF, régénération du mot de passe via `deploy`
  (et non `restart`), alignement README ↔ script.
- 🚧 Création de cette feuille de route et de `doc/CHANGELOG.md` (fichiers désormais présents, à committer).
- ⬜ Parcours « utilisateur externe » rejoué de bout en bout sur Vast.ai (Ubuntu 22.04, GTX 1660 Super).

Limites connues et assumées pour l'instant : une seule session Sunshine, driver NVIDIA préinstallé requis, pas d'auto-stop, pas de quota.

## Non-objectifs (version actuelle)

- Héberger une interface web, un catalogue de jeux ou un système de comptes.
- Facturer, mesurer un quota ou arrêter automatiquement la VM chez le provider.
- Prendre en charge les Pods conteneurs (RunPod Serverless, Clore.ai marketplace, Salad Cloud) : pas de UDP ni de Compose.
- Installer ou mettre à jour le driver NVIDIA (nécessite des redémarrages, contraire au principe du script).
- Gérer plusieurs joueurs simultanés sur un même GPU (nécessiterait Wolf et une refonte).

---

## Jalons

### v0.1 — Consolider le MVP · court terme 🚧

**Objectif** : n'importe qui suit le README et joue du premier coup, sans interpréter un message d'erreur.

| Tâche | État |
|---|---|
| Commiter les correctifs Tailscale / CSRF / mot de passe en cours | 🚧 |
| Publier `doc/feuille-de-route.md` et `doc/CHANGELOG.md` | 🚧 / ⬜ |
| Rejouer le déploiement complet sur Vast.ai et corriger les écarts de doc | ⬜ |
| Ajouter `bash deploy.sh doctor` (pré-vol) : `nvidia-smi`, archi, OS, `docker compose`, fichiers existants | ⬜ |
| CI minimale : `bash -n deploy.sh` + `shellcheck` + vérification des liens relatifs du README | ⬜ |

**Critères d'acceptation** : déploiement en < 10 min depuis une VM vierge ; pairing Moonlight réussi ; `help` et `status` cohérents avec le README ; CI verte. **Livrable** : tag `v0.1.0`.

### v0.2 — Fiabilité & opérations · 0–1 mois ⬜

**Objectif** : rendre les opérations courantes sûres et réversibles sans ajouter de service.

- ⬜ **Idempotence renforcée** : `deploy` relançable N fois sans recréer le conteneur inutilement ; distinction claire entre `deploy` (relit `.env`) et `restart` (ne le relit pas).
- ⬜ **Commande `upgrade`** : `compose pull` + recreation uniquement si l'image change ; garder les données.
- ⬜ **Commande `rotate-password`** : remplace la manipulation manuelle de `sed` documentée aujourd'hui, met à jour les deux variables et relance proprement.
- ⬜ **Commandes `backup` / `restore`** : archive de `.env` + configs + sauvegardes (gros répertoires de jeux exclus et documentés).
- ⬜ **Contrôles post-déploi** : ports en écoute (`ss`), santé de `https://127.0.0.1:47990`, image et GPU effectivement utilisés par le conteneur.
- ⬜ **Tests bash légers** (`bats` ou équivalent) sur `write_env`, `cmd_csrf` et le parseur de commandes.

**Critères d'acceptation** : deux `deploy` consécutifs sans perte de sauvegarde ni de pairing ; rotation de mot de passe en une commande ; restauration testée ; CI verte.

### v0.3 — Réseau privé par défaut · 1–2 mois ⬜

**Objectif** : ne plus dépendre d'une IP publique pour jouer, sans casser le parcours simple.

- ⬜ Guide « **Tailscale-first** » : installation, `tailscale up`, `csrf`, hôte Moonlight en `100.x.y.z`.
- ⬜ `csrf` accepte plusieurs origines (séparées par des virgules) et conserve les origines existantes.
- ⬜ Détection et correction automatiques de l'origine CSRF après changement d'IP tailscale.
- ⬜ Parameters `CLOUDYPAD_EXPOSE_PUBLIC=0|1` : ne mapper les ports que sur le réseau privé quand c'est possible ; documenter le compromis (Moonlight hors réseau = VPN requis).
- ⬜ Doc « VM recréée, nouvelle IP » : mise à jour de l'hôte Moonlight sans réinstaller.

**Critères d'acceptation** : VM joignable uniquement via Tailscale, pairing et streaming fonctionnels, aucune erreur CSRF après redémarrage ou changement d'IP.

### v0.4 — Élargissement des fournisseurs · 2–3 mois ⬜

**Objectif** : ne pas être dépendant d'un seul marché spot.

- ⬜ Valider et documenter **TensorDock** (VPS Ubuntu + UDP) avec le même script.
- ⬜ Guide générique **VM classique** (OVH / Scaleway / AWS) : pare-feu, IP publique, clé SSH.
- ⬜ Réévaluer **Clore.ai bare metal** (engagement 14–30 j) ; la marketplace reste explicitement non supportée.
- ⬜ Tableau de compatibilité versionné dans le README, avec date de dernière vérification.
- 💡 **Image maison** construite par GitHub Actions et publiée sur `ghcr.io/<fork>/sunshine`, pinée par digest, avec commande `upgrade` correspondante.

**Critères d'acceptation** : déploiement réussi chez **au moins deux fournisseurs** ; aucun chemin spécifique à Vast.ai dans `deploy.sh` ; prix indicatifs mis à jour.

### v0.5 — Coût & cycle de vie · 3–4 mois ⬜

**Objectif** : éviter les mauvaises surprises (facture, données perdues) sans piloter le provider à la place de l'utilisateur.

- ⬜ Commande `cost [€/h]` : estimation $/h → $/mois selon usage hebdomadaire, rappel que `stop` n'arrête pas la facturation.
- ⬜ `purge` demande une confirmation explicite et affiche un récapitulatif de ce qui sera supprimé ; `backup` automatique avant purge.
- ⬜ `update-ip` : réaffiche l'IP et les instructions Moonlight après recréation de la VM.
- 💡 **Auto-stop sur inactivité** : détection via les logs/API Sunshine puis `stop` du conteneur ; **uniquement si** l'utilisateur l'active explicitement et après étude de fiabilité.
- 💡 Planification « démarrer/arrêter » via cron côté VM, sans accès API provider.

**Critères d'acceptation** : `purge` refuse de supprimer sans confirmation ; documentation coût complète ; aucune commande ne contacte l'API d'un provider sans configuration explicite.

### v1.0 — Première release stable · 4–6 mois ⬜

**Objectif** : une version datée, reproductible, que d'autres peuvent forker sereinement.

- ⬜ Matrice testée : Ubuntu 22.04 / 24.04 × GPU (1660S, 3060, 3090/4090) × providers (Vast.ai, TensorDock).
- ⬜ `CHANGELOG.md` complet, tag `v1.0.0`, notes de release, checksum de `deploy.sh`.
- ⬜ Revue de conformité AGPL : provenance de l'image, mentions de licence, modèle de fork.
- ⬜ Enquête rapide auprès de 3 utilisateurs externes avant de figer la v1.

**Critères d'acceptation** : checklist de release validée ; README et docs sans lien mort ; aucun correctif bloquant ouvert.

---

## Idées en réserve (non planifiées) 💡

| Idée | Intérêt | Pourquoi ce n'est pas encore prioritaire |
|---|---|---|
| **Wolf** au lieu de Sunshine pour plusieurs sessions | Multi-joueurs sur un GPU | Change le modèle « un utilisateur, une VM » et complexifie le script |
| Image Docker custom (Steam/Heroic préconfigurés) | Démarrage plus rapide | Dépendance à une CI et à un registre à maintenir |
| Tunnel UDP-over-TCP (`udp2raw`, WireGuard sur TCP) | Débloquer RunPod / Clore.ai conteneurs | Latence et complexité ; contraire à la simplicité visée |
| Petit tableau de bord client (bitrate, latence) | Diagnostic | Nécessite un service ou un binaire local ; hors périmètre |
| Traduction anglaise complète | Audience plus large | Le projet est né francophone ; à faire après stabilisation |

## Risques et arbitrages

| Risque / question | Mitigation ou décision à prendre |
|---|---|
| L'image amont `0.46.0` change ou disparaît | Pin par digest + miroir maison en v0.4 ; documenter la procédure d'upgrade |
| Mauvais sens de variable `.env` (`PASSWORD` vs `PASSWORD_BASE64`) | Centraliser dans la commande `rotate-password` (v0.2), interdire l'édition manuelle dans le README |
| `restart` relu comme un rechargement de config | Messages explicites dans `help`, `status` et documentation (déjà en cours) |
| IP changée à chaque relocation Vast.ai | Tailscale par défaut (v0.3) + commande `update-ip` (v0.5) |
| Dérive vers un « vrai » service cloud gaming | Garder les non-objectifs en tête de ce document et refuser toute fonctionnalité qui impose un backend |
| Conformité AGPL en cas de fork hébergé | Maintenir la section licence du README et un `NOTICE` si image modifiée |

## Rythme et conventions

- Versions `vMAJEUR.MINEUR.PATCH` ; `-rc` pour les candidats release. Chaque commande livrée = une entrée dans `CHANGELOG.md`.
- Une petite étape par PR, avec `bash -n` et `shellcheck` verts ; changement de doc dans la même PR.
- Priorité toujours : **fonctionne chez un utilisateur externe** > élégance du script > nouvelles fonctionnalités.
- Réévaluer cette feuille de route à chaque tag ; déplacer en « réserve » ce qui n'a pas bougé depuis deux jalons.
