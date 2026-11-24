# Changelog

Toutes les évolutions notables de **Libre Cloud Gaming** (`cloudiste-pad`) sont consignées ici.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versions sémantiques
`MAJEUR.MINEUR.PATCH`. La v0.1.0 n'est pas encore taguée.

Légende : **Ajouté** · **Modifié** · **Corrigé** · **Supprimé**.

---

## [Non publié] — v0.1.0 « MVP déployable » — 2026-11-24 🚧

### Ajouté

- [`doc/feuille-de-route.md`](feuille-de-route.md) : vision, garde-fous, non-objectifs et jalons v0.1 → v1.0 avec critères d'acceptation.
- Ce fichier `doc/CHANGELOG.md`, désormais lié depuis le README.
- Lien vers les deux documents dans l'introduction du README.

### Modifié

- Nom par défaut affiché dans Moonlight : **Cloudiste PAD** au lieu de `Cloudypad` (`CLOUDYPAD_SERVER_NAME` / `SUNSHINE_SERVER_NAME`). Sur une VM déjà déployée, modifier `SUNSHINE_SERVER_NAME` dans `.env` puis relancer `deploy`.
- README : prérequis **x86_64 / amd64** vérifié par `deploy.sh`.
- README : régénération du mot de passe Sunshine via `bash deploy.sh deploy` (et non plus `restart`), avec explication du rôle des deux variables `.env`.
- README : avertissement selon lequel `docker compose restart` ne relit pas `.env`, valable aussi pour le CSRF après installation de Tailscale.
- README : `csrf [url]` ajouté à la liste des commandes ; firewall du provider remplacé par une formulation générique (plus de référence à RunPod).
- `deploy.sh` : en-têtes et messages alignés sur **Vast.ai / TensorDock / VM classique** (RunPod retiré des prérequis et du message final).
- `deploy.sh` : description de `start` / `stop` clarifiée — arrêter le conteneur n'arrête **pas** la facturation de la VM.
- `deploy.sh` : correction d'une faute dans le commentaire sur le fallback XTest de `libvirtualhid`.

### À faire avant le tag

- Rejouer le déploiement complet sur Vast.ai (Ubuntu 22.04, GTX 1660 Super).
- Ajouter `bash deploy.sh doctor` et une CI `bash -n` / `shellcheck`.
- Voir la [feuille de route](feuille-de-route.md) pour le détail.

---

## Historique avant v0.1.0 — 2026-11-24

Aucun tag n'avait été publié ; les commits sont conservés tels quels.

| Commit | Résumé |
|---|---|
| `8eb8a61` | Clarify Tailscale setup after initial deploy — table « Tailscale installé avant/après le premier `deploy` », commande `csrf` et cas du `restart` insuffisant. |
| `8a9edd0` | Document Sunshine password regeneration — procédure de renouvellement du mot de passe et mise à jour des deux variables `.env`. |
| `e2dcf1b` | Merge branch 'main' of `https://github.com/nazimboudeffa/cloudiste-pad.git`. |
| `05eab71` | Remove landing page and its README link — retour à un dépôt sans site statique. |
| `88978bc` | Add GNU AGPL v3 License — fichier `LICENSE` et obligation de source ouverte en cas de service exposé. |
| `aca4cfe` | Add static landing page describing the Cloudypad fork — page ajoutée puis retirée dans `05eab71`. |
| `9c477bf` | Initial import — `deploy.sh` (Docker Compose, Sunshine, Moonlight) et tutoriel `doc/vast-ai.md`. |

---

## Conventions

- Chaque commande ou comportement livré ajoute une entrée dans la section `[Non publié]` ; au tag, elle devient une section datée `## [vX.Y.Z] — AAAA-MM-JJ`.
- Une correction qui ne casse pas l'interface utilisateur incrémente `PATCH` ; une nouvelle commande incrémente `MINEUR`.
- Un changement de modèle (ex. Wolf au lieu de Sunshine, passage à un backend) incrémente `MAJEUR` et implique une mise à jour de la [feuille de route](feuille-de-route.md) et du README.
