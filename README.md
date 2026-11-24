# Libre Cloud Gaming

Une minuscule plateforme de cloud gaming **autonome**, construite à partir des briques open-source de [Cloudy Pad](https://github.com/PierreBeucher/cloudypad).

Pas de base de données, pas de compte utilisateur, pas d'interface web à héberger : **un seul script**, lancé directement sur une machine GPU louée chez Vast.ai, TensorDock ou chez un fournisseur de VM classique, et tu joues via Moonlight.

```
[Ta machine]
  └─ Moonlight ──────── streaming ────────┐
                                          │
[VM GPU Vast / TensorDock / cloud VM]     │
  └─ driver NVIDIA                        │
      └─ Docker + NVIDIA Container Toolkit│
          └─ container "cloudy" ──────────┘
              ├─ KDE Plasma
              ├─ Steam / Heroic / Proton
              └─ serveur Sunshine
```

> ⚠️ Cloudy Pad est sous licence **AGPL-3.0**. Si tu modifies le projet et exposes un service accessible via réseau, tu dois proposer le code source correspondant. Le code de l'app officielle `app.cloudypad.gg` n'est pas dans le dépôt public : ici on repart donc de l'image Docker et des concepts du projet.

> ⚠️ **Les Pods RunPod et les orders Docker Clore.ai ne conviennent pas à Moonlight** : ce sont des conteneurs (pas de Docker Compose) et ils ne supportent pas les ports UDP nécessaires au streaming. Voir les sections « Choix du fournisseur » et « Déploiement depuis GitHub / RunPod ».

> 🗺️ Versions, jalons et idées à venir : [`doc/feuille-de-route.md`](doc/feuille-de-route.md) · historique : [`doc/CHANGELOG.md`](doc/CHANGELOG.md).

---

## Choix du fournisseur

Tous les GPU cloud pas chers ne se valent pas ici. `deploy.sh` a besoin d’une **VM complète** (systemd + Docker Compose), d’un **accès SSH** et de **ports UDP** exposés.

| Fournisseur | Prix indicatif / h | VM + SSH | UDP | Docker Compose | Compatible avec ce projet |
|---|---|---|---|---|---|
| **Vast.ai** (VM Ubuntu) | GTX 1660S ~$0,03–0,08 · RTX 3090 ~$0,09–0,20 · RTX 4090 ~$0,23–0,44 | ✅ | ✅ | ✅ | ✅ **recommandé** |
| **TensorDock** (VPS) | RTX 4090 ~$0,35 | ✅ | ✅ | ✅ | ✅ |
| VM classique (Scaleway, AWS…) | variable | ✅ | ✅ | ✅ | ✅ |
| **Clore.ai** (marketplace) | RTX 3090 ~$0,02–0,05 · RTX 4090 ~$0,07–0,12 | ❌ conteneur | ❌ (`tcp`/`http` seulement) | ❌ | ❌ |
| **Clore.ai** (bare metal) | sur devis | ✅ | ✅ | ✅ | ⚠️ 14 à 30 jours minimum |
| **RunPod** Pods | RTX 4090 ~$0,34–0,89 | ❌ conteneur | ❌ | ❌ | ❌ |
| Salad Cloud / RunPod Serverless | RTX 3090 ~$0,09 chez Salad | ❌ conteneur | ❌ | ❌ | ❌ |

Prix indicatifs de novembre 2026, souvent des offres **spot** dont la disponibilité varie. Vérifie aussi le CPU, la RAM, le disque et la bande passante montante de l’offre.

⚠️ **Clore.ai mérite une réserve** : leur blog annonce des prix 3 à 10× inférieurs, mais leurs locations « marketplace » sont un **seul conteneur** (pas de Docker Compose) et le forwarding n’accepte que `tcp` et `http`, pas `udp`. Leur guide Sunshine/Moonlight contourne le problème avec un conteneur unique en `network_mode: host` : notre `deploy.sh` ne fonctionne donc **pas tel quel**. Leur offre *bare metal* donne une vraie machine avec IP publique, mais avec un engagement de 14 à 30 jours minimum — pas adapté à un usage occasionnel.

### Quel GPU choisir

Pour du 1080p, une 4090 est surdimensionnée :

| Usage | GPU minimal | Prix indicatif |
|---|---|---|
| 1080p / 60 fps | GTX 1660 Super 6G ou RTX 2060 | ~$0,03–0,08/h |
| 1080p / 60 fps, meilleur NVENC | RTX 3060 12G | ~$0,06–0,10/h |
| 1440p / 60 fps | RTX 3080 / 3090 | ~$0,09–0,20/h |
| 4K / 60 fps | RTX 3090 / 4090 | ~$0,23–0,44/h |

Exemple : 3 h de jeu par semaine sur une 1660 Super à $0,05/h → environ **$0,60/mois**.

> 💡 Sur Vast.ai, choisis explicitement un **template VM Ubuntu** (pas une instance Docker), sinon Docker Compose n’est pas disponible. Les ports y sont attribués **aléatoirement** : récupère les ports externes dans « IP Port Info » ou via les variables `VAST_TCP_PORT_X` / `VAST_UDP_PORT_X`, puis utilise-les dans Moonlight et dans l’URL `https://IP:PORT`.

---

## Prérequis

### Sur ta machine

- [Moonlight](https://moonlight-stream.org/) installé (Windows, macOS, Linux, Android…)
- Un navigateur web
- Une connexion descendante d'au moins **20 Mbps**

### Sur la VM GPU

- **Ubuntu 22.04 ou 24.04**, architecture **x86_64 / amd64** (vérifiée par `deploy.sh`)
- **Driver NVIDIA déjà installé** (cas standard chez Vast.ai / TensorDock)
- **4 CPU / 8 Go RAM** minimum
- Une **IP publique**
- Accès SSH (`root` ou `ubuntu`)

Le script ne installe **pas** le driver NVIDIA et ne redémarre jamais la machine : la documentation Cloudy Pad déconseille l'installation en `localhost` via le provider SSH à cause des redémarrages multiples.

---

## 1. Louer la VM

Chez ton provider GPU (Vast.ai, TensorDock, ou une VM chez Scaleway/AWS…) :

👉 Tutoriel pas-à-pas pour Vast.ai : [`doc/vast-ai.md`](doc/vast-ai.md).

1. Choisis un GPU (voir le tableau « Quel GPU choisir » ; une GTX 1660 Super suffit pour du 1080p).
2. Choisis une image Ubuntu avec drivers NVIDIA.
3. Note l'IP publique, l'utilisateur SSH et le mot de passe / clé.
4. Ouvre les ports dans le **pare-feu du provider** :

| Protocole | Ports |
|---|---|
| TCP | `22`, `47984`, `47989`, `47990`, `48010` |
| UDP | `47998`, `47999`, `48000`, `48002` |

Si `ufw` est actif sur la VM :

```bash
sudo ufw allow 22/tcp
sudo ufw allow 47984:47990/tcp
sudo ufw allow 48010/tcp
sudo ufw allow 47998:48002/udp
```

---

## 2. Mettre le script sur la VM

### Option A — via SSH

Depuis ton PC :

```bash
scp deploy.sh root@IP_DE_LA_VM:/root/deploy.sh
ssh root@IP_DE_LA_VM
```

Si l'utilisateur SSH est `ubuntu` :

```bash
scp deploy.sh ubuntu@IP_DE_LA_VM:/home/ubuntu/deploy.sh
ssh ubuntu@IP_DE_LA_VM
```

### Option B — script de démarrage du provider

Colle ceci dans le champ *Startup script* / *cloud-init* :

```bash
cat > /root/deploy.sh <<'EOS'
# ... colle ici tout le contenu de deploy.sh ...
EOS
bash /root/deploy.sh deploy
```

Le `<<'EOS'` empêche le shell d'interpréter les `$` du script pendant la copie.

---

## 3. Déployer

Sur la VM :

```bash
# si tu es root
bash /root/deploy.sh deploy

# si tu es ubuntu
sudo bash /home/ubuntu/deploy.sh deploy
```

Le script :

1. vérifie le GPU avec `nvidia-smi` ;
2. installe Docker et le plugin `docker compose` si besoin ;
3. installe le NVIDIA Container Toolkit ;
4. génère un mot de passe Sunshine conservé dans `/opt/cloudypad/.env` ;
5. télécharge l'image `ghcr.io/pierrebeucher/cloudypad/sunshine:0.46.0` ;
6. démarre le conteneur `cloudy`.

Durée : quelques minutes selon le débit du provider.

À la fin, le script affiche l'IP publique (ou l'IP Tailscale `100.x.y.z` si Tailscale est déjà installé), l'utilisateur `cloudy`, le mot de passe généré et les instructions de pairing.

Si tu as perdu les identifiants :

```bash
grep -E '^(SUNSHINE_WEB_USERNAME|SUNSHINE_WEB_PASSWORD)=' /opt/cloudypad/.env
```

### Régénérer le mot de passe Sunshine

Si le mot de passe a été partagé par erreur, ou si tu veux simplement en changer, régénère-le directement sur la VM :

```bash
NEW_PASS="$(openssl rand -base64 24 | tr -d '\n')"
NEW_B64="$(printf '%s' "$NEW_PASS" | base64 | tr -d '\n')"

sed -i "s#^SUNSHINE_WEB_PASSWORD=.*#SUNSHINE_WEB_PASSWORD=${NEW_PASS}#" /opt/cloudypad/.env
sed -i "s#^SUNSHINE_WEB_PASSWORD_BASE64=.*#SUNSHINE_WEB_PASSWORD_BASE64=${NEW_B64}#" /opt/cloudypad/.env
chmod 600 /opt/cloudypad/.env

bash /root/deploy.sh deploy
grep -E '^SUNSHINE_WEB_(USERNAME|PASSWORD)=' /opt/cloudypad/.env
```

Les deux variables doivent être modifiées ensemble : `SUNSHINE_WEB_PASSWORD` est lue par le script (affichage final), `SUNSHINE_WEB_PASSWORD_BASE64` est celle utilisée par le conteneur. Relance `deploy` pour que Docker Compose relise `.env` et recrée le conteneur si besoin : les données (jeux, sauvegardes) et le pairing Moonlight ne sont pas touchés (le pairing repose sur un certificat, pas sur ce mot de passe).

> ⚠️ `bash deploy.sh restart` ne suffit **pas** : `docker compose restart` ne relit pas `.env` et garde les variables d'environnement du conteneur existant. C'est la même raison pour laquelle il faut `csrf` après l'installation de Tailscale (voir ci-dessous).

> Si tu as changé `CLOUDYPAD_DIR`, remplace `/opt/cloudypad` par ton chemin. Adapte aussi `/root/deploy.sh` si le script est installé ailleurs.

### Installer Tailscale après le déploiement

`deploy.sh` détecte Tailscale pour afficher l'IP `100.x.y.z` et pour autoriser l'origine CSRF `https://100.x.y.z:47990`. Aucun redémarrage de la VM n'est nécessaire, mais un simple `restart` du conteneur ne suffit pas : il ne relit pas `.env`.

| Situation | Commande |
|---|---|
| Tailscale installé avant le premier `deploy` | Rien de plus, le `deploy` initial a tout configuré. |
| Tailscale installé après le premier `deploy` | `bash /root/deploy.sh csrf` |
| Tu as seulement fait `bash /root/deploy.sh restart` | ❌ Ne suffit pas. |

```bash
tailscale up
tailscale ip -4

bash /root/deploy.sh csrf
bash /root/deploy.sh deploy   # optionnel : rafraîchit l'affichage final
```

`write_env()` ne remplit le CSRF que si la variable est vide ; la commande `csrf` la remplace toujours et recrée le conteneur. Si elle répond « Origine manquante », vérifie `command -v tailscale` et `tailscale ip -4`, puis utilise `bash /root/deploy.sh csrf https://100.x.y.z:47990`. Voir [`doc/vast-ai.md`](doc/vast-ai.md) pour l'installation de Tailscale sur Vast.ai.

---

## 4. Ouvrir l'interface Sunshine

Dans ton navigateur :

```text
https://IP_DE_LA_VM:47990
```

- Accepte l'avertissement sur le certificat self-signed.
- Connecte-toi avec :
  - utilisateur : `cloudy`
  - mot de passe : celui affiché par le script

Garde cet onglet ouvert pour l'étape suivante.

---

## 5. Pairer Moonlight

Dans Moonlight :

1. Clique sur **Add PC** / `+`.
2. Saisis l'IP publique de la VM.
3. Clique sur l'hôte.
4. Moonlight affiche un **code à 4 chiffres**.

Dans l'interface Sunshine (`https://IP:47990`) :

- Cherche la section **Pairing / PIN**.
- Saisis le code affiché par Moonlight.
- Valide.

Selon les versions de Sunshine, c'est parfois l'interface web qui affiche le code : dans ce cas, saisis-le dans Moonlight. L'hôte doit ensuite apparaître en vert / *online*.

---

## 6. Lancer la session

Clique sur l'hôte dans Moonlight, puis choisis :

- **Desktop** : le bureau KDE Plasma ;
- **Steam (Big Picture)** : arrivée directe dans Steam.

La première connexion peut prendre **1 à 3 minutes** : démarrage du serveur X, initialisation de la capture, mises à jour Steam.

Ensuite :

1. Connecte-toi à Steam avec ton propre compte.
2. Installe tes jeux.
3. Dans les réglages Moonlight, commence par **1080p / 20–30 Mbps**, puis augmente si la latence reste correcte.

---

## Commandes du script

```bash
bash deploy.sh deploy     # installe et démarre (défaut)
bash deploy.sh start      # redémarre le conteneur
bash deploy.sh stop       # arrête le conteneur
bash deploy.sh restart
bash deploy.sh status
bash deploy.sh logs       # suit les logs en direct
bash deploy.sh csrf [url] # autorise l'origine de pairing (Tailscale/NAT)
bash deploy.sh destroy    # supprime le conteneur, garde les données
bash deploy.sh purge      # supprime le conteneur ET les données
bash deploy.sh help
```

Variables d'environnement optionnelles :

| Variable | Défaut |
|---|---|
| `CLOUDYPAD_IMAGE` | `ghcr.io/pierrebeucher/cloudypad/sunshine:0.46.0` |
| `CLOUDYPAD_DIR` | `/opt/cloudypad` |
| `CLOUDYPAD_SERVER_NAME` | `Cloudypad` |
| `CLOUDYPAD_KEYBOARD_LAYOUT` | `fr` |
| `CLOUDYPAD_LOCALE` | `fr_FR.UTF-8` |

---

## Arrêter de payer

⚠️ `bash deploy.sh stop` arrête **le conteneur**, pas la facturation de la VM.

Pour ne rien payer pendant que tu ne joues pas :

```bash
bash /root/deploy.sh stop
```

Puis **arrête ou supprime la VM depuis l'interface du provider**.

Pour rejouer : redémarre la VM chez le provider, puis :

```bash
bash /root/deploy.sh start
```

Si la VM a été recréée, son IP peut changer : pense à mettre à jour l'hôte dans Moonlight.

---

## Déploiement depuis GitHub / RunPod

Runpod a bien une intégration GitHub, mais elle cible les **Serverless Endpoints** (un `handler.py` + un `Dockerfile`). Pour les **Pods**, tu peux utiliser un template personnalisé basé sur une image Docker, ou déployer un dépôt compatible Serverless depuis le Hub. Dans notre cas, deux limitations sont bloquantes :

1. **Docker Compose n'est pas supporté** dans un Pod : Runpod gère Docker pour toi, donc `deploy.sh` ne peut pas s'y exécuter tel quel.
2. **Les connexions UDP ne sont pas supportées** par les Pods (HTTP/TCP seulement). Or Moonlight utilise UDP pour la vidéo (`47998`), le contrôle (`47999`) et l'audio (`48000`).

Donc : **non, pas directement depuis GitHub vers un RunPod Pod avec Moonlight.**

| Option | Faisable | Commentaire |
|---|---|---|
| Vast.ai + image Docker construite par GitHub Actions | ✅ | Expose des ports UDP ; il faut « aplatir » la stack en une seule image (l'image Cloudypad Sunshine suffit) |
| VM classique + GitHub Actions appelant `cloudypad create ssh` | ✅ | Le plus fidèle à Cloudypad ; IP et clé SSH stockées dans les secrets du dépôt |
| RunPod Pod + tunnel UDP over TCP | ⚠️ | Possible avec `udp2raw` ou WireGuard sur TCP, mais latence et complexité |
| RunPod Serverless / Hub depuis GitHub | ❌ | Pensé pour des handlers HTTP, pas pour un bureau + Moonlight |

Si tu veux le mode « push sur GitHub → déploiement automatique », la prochaine étape serait d'ajouter `.github/workflows/deploy.yml` : le workflow se connecte en SSH à ta VM Vast.ai / TensorDock et lance `bash deploy.sh deploy`, avec l'hôte et la clé privée dans les secrets GitHub.

---

## Dépannage

| Symptôme | À vérifier |
|---|---|
| Moonlight ne voit pas l'hôte | Ports UDP ouverts chez le provider |
| Page `47990` inaccessible | Port TCP `47990` fermé ou conteneur arrêté |
| `nvidia-smi` ne voit rien | VM sans GPU ou driver manquant |
| Pairing échoue | Code saisi dans le mauvais sens ou onglet Sunshine fermé |
| Image noire / freeze | `bash deploy.sh logs` |
| Steam très lent au premier lancement | Mises à jour Steam en cours |

---

## Limites de cette version

- Sunshine gère **une session à la fois**. Pour plusieurs joueurs sur un même GPU, il faudrait utiliser **Wolf**.
- Pas de quota, ni de facturation, ni d'auto-stop intégré : c'est volontaire.
- Le driver NVIDIA doit déjà être présent sur la VM.
- Le script ne touche pas à la VM du provider : c'est toi qui décides de la démarrer, de l'arrêter ou de la supprimer.
