# Déployer sur Vast.ai

Tutoriel minimal pour lancer `deploy.sh` sur une **VM GPU Vast.ai** et jouer via Moonlight.

> ⚠️ Choisis bien une **VM**, pas une instance Docker : `deploy.sh` utilise Docker Compose, qui n’est disponible que dans les VM. Les instances Docker de Vast.ai ne conviennent pas.

---

## 1. Prérequis

- Un compte [Vast.ai](https://cloud.vast.ai) avec au moins ~$5 de crédit.
- **Ta clé SSH publique ajoutée dans Account → Keys avant de louer** : sans ça la VM sera inaccessible, et les clés ne peuvent pas être modifiées une fois la VM lancée.
- [Moonlight](https://moonlight-stream.org/) installé sur ton PC.
- [Tailscale](https://tailscale.com/download) installé sur ton PC (voir étape 4).

### Générer une clé SSH (si Vast.ai affiche « No SSH key found »)

Vérifie d’abord si tu as déjà une clé :

```bash
# Git Bash / Linux / macOS
ls -l ~/.ssh
```

```powershell
# PowerShell Windows
dir $env:USERPROFILE\.ssh
```

Si le dossier n’existe pas ou ne contient pas de fichier `id_ed25519.pub`, génère une paire de clés :

```bash
ssh-keygen -t ed25519 -C "ton-email@example.com"
```

Appuie sur **Entrée** aux trois questions (emplacement par défaut, pas de passphrase). Ça crée :

- `~/.ssh/id_ed25519` → **clé privée**, ne jamais la partager ;
- `~/.ssh/id_ed25519.pub` → **clé publique**, celle à donner à Vast.ai.

Affiche et copie la **clé publique** (une seule ligne, commence par `ssh-ed25519 AAAA...`) :

```bash
# Git Bash / Linux / macOS
cat ~/.ssh/id_ed25519.pub
```

```powershell
# PowerShell Windows
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

Va dans **Account → Keys** sur Vast.ai, colle cette ligne dans le champ prévu, puis enregistre. Le message « No SSH key found » doit disparaître et la clé doit apparaître dans la liste.

⚠️ Erreur fréquente : coller le contenu de `id_ed25519` (privée) au lieu de `id_ed25519.pub`. Si tu as collé la mauvaise clé, supprime-la et ajoute la bonne avant de louer la VM.

---

## 2. Louer la VM

1. Onglet **Search** : filtre GPU. Pour du 1080p, une **GTX 1660 Super**, une **RTX 2060** ou une **RTX 3060** suffit (~$0,03–0,10/h).
2. Filtre sur une machine **Ubuntu 22.04 avec driver NVIDIA déjà installé**, au moins **4 CPU / 8 Go RAM / 40 Go de disque**.
3. Sélectionne un **template VM Ubuntu** (par exemple *Ubuntu 22.04 VM*), pas une image Docker.
4. Préferre un GPU proche de chez toi (latence) et une machine avec une bonne bande passante montante.
5. Clique sur **Rent**. Attends que le bouton de l’instance affiche **CONNECT**.
6. Copie la commande SSH donnée dans la console, de la forme :

```bash
ssh -p <port-ssh> root@<ip-de-la-machine>
```

> Le port SSH et même l’IP peuvent être des ports/publics partagés : Vast.ai attribue les ports **aléatoirement**. C’est normal.

---

## 3. Copier et lancer le script

Depuis ton PC :

```bash
scp -i ~/.ssh/id_ed25519 -P <port-ssh> deploy.sh root@<ip-de-la-machine>:/root/deploy.sh
ssh -i ~/.ssh/id_ed25519 -p <port-ssh> root@<ip-de-la-machine>
```

Sous PowerShell Windows, remplace `~/.ssh/id_ed25519` par `$env:USERPROFILE\.ssh\id_ed25519`.

Puis, **dans la VM** :

```bash
bash /root/deploy.sh deploy
```

Ou plus simplement

Sur ton PC :

```bash
ssh -i ~/.ssh/id_ed25519 -p <port-ssh> root@<ip-de-la-machine>
```

Puis, **dans la VM** :

```bash
curl -fsSL https://raw.githubusercontent.com/nazimboudeffa/cloudiste-pad/main/deploy.sh -o deploy.sh
bash deploy.sh deploy
```

Le script vérifie `nvidia-smi`, installe Docker et le NVIDIA Container Toolkit, puis démarre le conteneur `cloudy`. Note le **mot de passe Sunshine** affiché à la fin (il est aussi dans `/opt/cloudypad/.env`).

Vérification rapide :

```bash
bash /root/deploy.sh status
nvidia-smi -L
```

### Régénérer le mot de passe Sunshine

Le mot de passe affiché par le script est aussi enregistré dans `/opt/cloudypad/.env`. Pour le remplacer (par exemple après l’avoir collé dans un chat ou un ticket), exécute sur la VM :

```bash
NEW_PASS="$(openssl rand -base64 24 | tr -d '\n')"
NEW_B64="$(printf '%s' "$NEW_PASS" | base64 | tr -d '\n')"

sed -i "s#^SUNSHINE_WEB_PASSWORD=.*#SUNSHINE_WEB_PASSWORD=${NEW_PASS}#" /opt/cloudypad/.env
sed -i "s#^SUNSHINE_WEB_PASSWORD_BASE64=.*#SUNSHINE_WEB_PASSWORD_BASE64=${NEW_B64}#" /opt/cloudypad/.env
chmod 600 /opt/cloudypad/.env

bash /root/deploy.sh restart
grep -E '^SUNSHINE_WEB_(USERNAME|PASSWORD)=' /opt/cloudypad/.env
```

Il faut mettre à jour `SUNSHINE_WEB_PASSWORD` **et** `SUNSHINE_WEB_PASSWORD_BASE64`, puis redémarrer le conteneur. Le pairing Moonlight déjà effectué reste valide : il utilise un certificat, pas ce mot de passe.

---

## 4. Accéder à Sunshine : Tailscale (recommandé)

Sur Vast.ai, les ports externes sont attribués **au hasard**. Moonlight s’attend à ce que les ports se suivent (47989, 47990, 48010, 47998…) : avec des ports aléatoires, le pairing échoue souvent. **Tailscale évite complètement le problème** : aucun port à ouvrir, Moonlight utilise une IP privée sur laquelle tous les ports sont accessibles.

### Sur la VM

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

Ouvre le lien affiché, authentifie-toi, puis récupère l’IP :

```bash
tailscale ip -4
```

### Sur ton PC

Installe Tailscale, connecte-toi au **même compte**, puis utilise l’IP `100.x.y.z` de la VM dans les étapes suivantes.

> La doc Vast.ai recommande aussi Tailscale pour le streaming Moonlight sur ses templates *Ubuntu Desktop (VM)*.

### Faut-il relancer `deploy.sh` après l’installation ?

Le service `tailscaled` démarre tout seul : **aucun redémarrage de la VM n’est nécessaire**. En revanche, `deploy.sh` ne recalcule l’IP et l’origine CSRF que lorsque tu lances certaines commandes.

| Moment de l’installation | Commande à lancer |
|---|---|
| Tailscale installé **avant** le premier `bash /root/deploy.sh deploy` | Rien de plus : le déploiement initial a déjà écrit `CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=https://100.x.y.z:47990`. |
| Tailscale installé **après** le premier `deploy` (cas fréquent) | `bash /root/deploy.sh csrf` |
| Tu as seulement fait `bash /root/deploy.sh restart` | ❌ **Ne suffit pas** : `restart` ne relit pas `.env` et ne met pas à jour l’origine CSRF. |

Séquence complète quand Tailscale arrive après le déploiement :

```bash
tailscale up
tailscale ip -4

bash /root/deploy.sh csrf
bash /root/deploy.sh deploy   # optionnel : rafraîchit seulement l’affichage final
```

Pourquoi cette différence : `write_env()` n’écrit l’origine CSRF que si `CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS` est **vide**. La commande `csrf`, elle, remplace toujours la valeur et recrée le conteneur.

Si `csrf` répond « Origine manquante », vérifie :

```bash
command -v tailscale
tailscale ip -4
```

Puis passe l’origine en dur :

```bash
bash /root/deploy.sh csrf https://100.x.y.z:47990
```

### Alternative sans Tailscale

Dans les paramètres du template, section **Ports**, demande les ports internes :

- TCP : `47984`, `47989`, `47990`, `48010`
- UDP : `47998`, `47999`, `48000`, `48002`

Récupère ensuite les ports externes dans **IP Port Info** ou via les variables `VAST_TCP_PORT_47990`, `VAST_UDP_PORT_47998`, etc. Utilise-les pour l’URL `https://IP:PORT_EXTERNE` et pour Moonlight. C’est plus fragile : le mapping aléatoire casse fréquemment le pairing.

---

## 5. Pairer Moonlight

1. Dans le navigateur : `https://100.x.y.z:47990` (IP Tailscale) → accepte le certificat self-signed.
2. Connecte-toi avec `cloudy` et le mot de passe généré par le script.
3. Dans Moonlight : **Add PC** → saisis l’IP Tailscale `100.x.y.z`.
4. Moonlight affiche un **PIN à 4 chiffres** → saisis-le dans la page Sunshine, section **PIN**.
   > Si tu obtiens **« CSRF Protection Error »**, l’IP Tailscale n’est pas autorisée. Lance `bash /root/deploy.sh csrf` sur la VM (le script détecte l’IP Tailscale et recrée le conteneur), puis réessaie. Tu peux aussi passer l’origine à la main : `bash /root/deploy.sh csrf https://100.x.y.z:47990`.
5. Clique sur l’hôte, puis sur **Desktop** (ou **Steam Big Picture**).

Première connexion : 1 à 3 minutes (démarrage du serveur X, mises à jour Steam).

---

## 6. Arrêter et ne pas payer

```bash
bash /root/deploy.sh stop
```

⚠️ Ça n’arrête **pas la facturation**. Pour ne plus payer, **termine l’instance depuis la console Vast.ai**.

Les jeux installés sont sur le disque de l’instance : sauvegarde-les avant de la supprimer si tu veux les garder. Redémarre une VM plus tard → il faudra relancer `deploy.sh` et récupérer une nouvelle IP Tailscale.

---

## Dépannage

| Symptôme | Solution |
|---|---|
| VM inaccessible en SSH | Clé **publique** (`id_ed25519.pub`) ajoutée dans Account → Keys avant la location, et `-i ~/.ssh/id_ed25519` utilisé dans la commande ? |
| `docker: command not found` | Tu as loué une instance Docker au lieu d’une VM |
| `nvidia-smi` introuvable | Choisis une image avec driver NVIDIA préinstallé |
| Page `47990` inaccessible | Utilise l’IP Tailscale, ou vérifie les ports dans le template |
| Conteneur `unhealthy` | L’image `0.46.0` exige `CLOUDYPAD_SUNSHINE_MAX_BITRATE` et `CLOUDYPAD_SUNSHINE_ADDITIONAL_CONFIG`. Relance `bash /root/deploy.sh deploy` avec un `deploy.sh` à jour, puis `docker exec cloudy supervisorctl status` |
| Moonlight ne pair pas | Ports aléatoires → passe par Tailscale |
| Souris/clavier inactifs dans Moonlight | Xorg ne capte pas les devices `uinput` créés dans le conteneur. Le script monte `/dev/null` sur `/dev/uinput` pour forcer le fallback **XTest** de libvirtualhid. Ferme complètement Moonlight puis reconnecte-toi |
| `h264_nvenc: Cannot load libnvidia-encode.so.1` | Ajoute `NVIDIA_DRIVER_CAPABILITIES: all` dans le compose (déjà présent dans le `deploy.sh` corrigé) |
| `av1_nvenc: Codec not supported` | Normal sur RTX 30xx : pas d’encodeur AV1. Utilise **H.264** ou **HEVC** dans Moonlight |
| Écran noir | `bash /root/deploy.sh logs` |

---

## Coût indicatif

| GPU | 1080p | Prix indicatif |
|---|---|---|
| GTX 1660 Super / RTX 2060 | 60 fps | ~$0,03–0,08/h |
| RTX 3060 12G | 60 fps, meilleur NVENC | ~$0,06–0,10/h |
| RTX 3090 / 4090 | 1440p / 4K | ~$0,09–0,44/h |

À 3 h/semaine sur une 1660 Super à $0,05/h : **~$0,60/mois**.
