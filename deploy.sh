#!/usr/bin/env bash
#
# Cloudypad "one-pod" - script autonome pour une VM GPU RunPod / Vast / TensorDock.
#
# Aucun backend, aucune base de donnees, aucun compte. Une seule machine, un seul
# utilisateur. Le script tourne DIRECTEMENT sur la VM GPU louee.
#
# Usage:
#   bash deploy.sh deploy     # installe et demarre (defaut si aucun argument)
#   bash deploy.sh start      # redemarre le container
#   bash deploy.sh stop       # arrete le container (Evite de payer le GPU)
#   bash deploy.sh restart
#   bash deploy.sh status
#   bash deploy.sh logs       # suit les logs en direct
#   bash deploy.sh csrf [url] # autorise une origine pour le pairing (Tailscale/NAT)
#   bash deploy.sh destroy    # supprime le container, garde les donnees
#   bash deploy.sh purge      # supprime le container ET les donnees
#   bash deploy.sh help
#
# Variables d'environnement optionnelles:
#   CLOUDYPAD_IMAGE        image Docker (defaut: ghcr.io/pierrebeucher/cloudypad/sunshine:0.46.0)
#   CLOUDYPAD_DIR          ou installer les fichiers (defaut: /opt/cloudypad)
#   CLOUDYPAD_SERVER_NAME  nom affiche dans Moonlight (defaut: Cloudypad)
#   CLOUDYPAD_KEYBOARD_LAYOUT / CLOUDYPAD_LOCALE
#
# Prerequis: Ubuntu 22/24 avec driver NVIDIA DEJA installe (cas standard RunPod/Vast).
# Le script n'installe PAS le driver NVIDIA: il ne redemarre jamais la machine.
#

set -Eeuo pipefail

CONTAINER="cloudy"
BASE_DIR="${CLOUDYPAD_DIR:-/opt/cloudypad}"
ENV_FILE="$BASE_DIR/.env"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"
DATA_DIR="$BASE_DIR/data"
HOME_DIR="$BASE_DIR/home"
HEROIC_DIR="$BASE_DIR/heroic"
IMAGE="${CLOUDYPAD_IMAGE:-ghcr.io/pierrebeucher/cloudypad/sunshine:0.46.0}"

log()  { printf '\n\033[1;36m[cloudypad]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[cloudypad]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[cloudypad]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
}

need_root() {
  if [[ "$EUID" -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
  fi
}

check_env() {
  command -v nvidia-smi >/dev/null 2>&1 \
    || die "nvidia-smi introuvable. Ce script attend un driver NVIDIA deja installe (standard RunPod/Vast)."
  nvidia-smi -L >/dev/null 2>&1 \
    || die "nvidia-smi ne voit aucun GPU. Verifie le driver NVIDIA de la VM."

  [[ "$(uname -m)" == "x86_64" ]] || die "Architecture non supportee: $(uname -m) (amd64 requis)."

  local id=""
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
  fi
  [[ "$id" == "ubuntu" ]] || warn "OS '$id' non teste (Ubuntu 22/24 recommande). On tente quand meme."

  log "GPU detecte:"
  nvidia-smi -L | sed 's/^/  /'
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Installation de Docker..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl gnupg docker.io docker-compose-plugin
  fi

  if ! docker compose version >/dev/null 2>&1; then
    log "Installation du plugin docker compose..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-compose-plugin
  fi
  docker compose version >/dev/null 2>&1 \
    || die "Le plugin 'docker compose' est absent apres installation."

  if ! dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then
    log "Installation du NVIDIA Container Toolkit..."
    install -m 0755 -d /usr/share/keyrings
    rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nvidia-container-toolkit
  fi

  log "Configuration du runtime Docker NVIDIA..."
  nvidia-ctk runtime configure --runtime=docker
  systemctl enable --now docker >/dev/null 2>&1 || true
  systemctl restart docker
}

prepare_dirs() {
  mkdir -p "$DATA_DIR" "$HOME_DIR" "$HEROIC_DIR"
  chown -R 1001:1001 "$DATA_DIR" "$HOME_DIR" "$HEROIC_DIR" || true
}

write_env() {
  local password key line

  if [[ ! -f "$ENV_FILE" ]]; then
    password="$(openssl rand -base64 24 | tr -d '\n')"

    cat > "$ENV_FILE" <<EOF
CLOUDYPAD_IMAGE=$IMAGE
CLOUDYPAD_DATA_DIR=$DATA_DIR
CLOUDYPAD_HOME_DIR=$HOME_DIR
CLOUDYPAD_HEROIC_DIR=$HEROIC_DIR
CLOUDYPAD_SHM_SIZE=${CLOUDYPAD_SHM_SIZE:-4gb}
CLOUDYPAD_KEYBOARD_LAYOUT=${CLOUDYPAD_KEYBOARD_LAYOUT:-fr}
CLOUDYPAD_KEYBOARD_MODEL=${CLOUDYPAD_KEYBOARD_MODEL:-}
CLOUDYPAD_KEYBOARD_VARIANT=${CLOUDYPAD_KEYBOARD_VARIANT:-}
CLOUDYPAD_KEYBOARD_OPTIONS=${CLOUDYPAD_KEYBOARD_OPTIONS:-}
CLOUDYPAD_LOCALE=${CLOUDYPAD_LOCALE:-fr_FR.UTF-8}
CLOUDYPAD_SUNSHINE_ADDITIONAL_CONFIG=${CLOUDYPAD_SUNSHINE_ADDITIONAL_CONFIG:-}
CLOUDYPAD_SUNSHINE_MAX_BITRATE=${CLOUDYPAD_SUNSHINE_MAX_BITRATE:-0}
CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=${CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS:-}
SUNSHINE_SERVER_NAME=${CLOUDYPAD_SERVER_NAME:-Cloudypad}
SUNSHINE_WEB_USERNAME=cloudy
SUNSHINE_WEB_PASSWORD=$password
SUNSHINE_WEB_PASSWORD_BASE64=$(printf '%s' "$password" | base64 | tr -d '\n')
EOF
    chmod 600 "$ENV_FILE"
    log "Identifiants Sunshine generes dans $ENV_FILE"
  else
    log "Configuration existante conservee: $ENV_FILE"
  fi

  # L'image 0.46.0 refuse de demarrer si ces variables sont absentes.
  # On les ajoute si besoin sans ecraser les valeurs deja configurees.
  while IFS= read -r line; do
    key="${line%%=*}"
    grep -q "^${key}=" "$ENV_FILE" || printf '%s\n' "$line" >> "$ENV_FILE"
  done <<EOF
CLOUDYPAD_KEYBOARD_MODEL=
CLOUDYPAD_KEYBOARD_VARIANT=
CLOUDYPAD_KEYBOARD_OPTIONS=
CLOUDYPAD_SUNSHINE_ADDITIONAL_CONFIG=
CLOUDYPAD_SUNSHINE_MAX_BITRATE=0
CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=
EOF

  # Si Tailscale est deja installe, on autorise directement son IP dans le
  # pairing Moonlight (Sunshine 2026 protege les actions Web par CSRF).
  if command -v tailscale >/dev/null 2>&1; then
    local ts_ip=""
    ts_ip="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
    if [[ -n "$ts_ip" ]] && grep -q '^CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=$' "$ENV_FILE"; then
      sed -i "s#^CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=\$#CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=https://${ts_ip}:47990#" "$ENV_FILE"
      log "Origine Tailscale ajoutee: https://${ts_ip}:47990"
    fi
  fi
}

write_compose() {
  cat > "$COMPOSE_FILE" <<'EOF'
services:
  cloudy:
    image: ${CLOUDYPAD_IMAGE}
    container_name: cloudy
    restart: unless-stopped
    privileged: true
    gpus: all
    shm_size: "${CLOUDYPAD_SHM_SIZE}"

    devices:
      - /dev/input:/dev/input

    device_cgroup_rules:
      - "c 13:* rmw"

    # Dans un conteneur, Xorg ne recoit pas les evenements de hotplug des
    # peripheriques uinput crees par Sunshine : la souris ne bouge pas.
    # On neutralise /dev/uinput pour forcer le fallback XTest de libvirtualhid,
    # qui injection directement dans le serveur X (libXtst).
    volumes:
      - /dev/null:/dev/uinput
      - ${CLOUDYPAD_DATA_DIR}:/cloudy/data
      - ${CLOUDYPAD_HOME_DIR}:/home/cloudy
      - ${CLOUDYPAD_HEROIC_DIR}:/home/cloudy/.config/heroic

    ports:
      - "47984:47984/tcp" # HTTPS
      - "47989:47989/tcp" # HTTP
      - "47990:47990/tcp" # Web UI
      - "48010:48010/tcp" # RTSP
      - "47998:47998/udp" # Video
      - "47999:47999/udp" # Control
      - "48000:48000/udp" # Audio
      - "48002:48002/udp" # Mic

    environment:
      NVIDIA_DRIVER_CAPABILITIES: all
      CLOUDYPAD_KEYBOARD_LAYOUT: ${CLOUDYPAD_KEYBOARD_LAYOUT}
      CLOUDYPAD_KEYBOARD_MODEL: ${CLOUDYPAD_KEYBOARD_MODEL}
      CLOUDYPAD_KEYBOARD_VARIANT: ${CLOUDYPAD_KEYBOARD_VARIANT}
      CLOUDYPAD_KEYBOARD_OPTIONS: ${CLOUDYPAD_KEYBOARD_OPTIONS}
      CLOUDYPAD_LOCALE: ${CLOUDYPAD_LOCALE}
      CLOUDYPAD_SUNSHINE_ADDITIONAL_CONFIG: ${CLOUDYPAD_SUNSHINE_ADDITIONAL_CONFIG}
      CLOUDYPAD_SUNSHINE_MAX_BITRATE: ${CLOUDYPAD_SUNSHINE_MAX_BITRATE}
      CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS: ${CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS}
      SUNSHINE_SERVER_NAME: ${SUNSHINE_SERVER_NAME}
      SUNSHINE_WEB_USERNAME: ${SUNSHINE_WEB_USERNAME}
      SUNSHINE_WEB_PASSWORD_BASE64: ${SUNSHINE_WEB_PASSWORD_BASE64}
EOF
}

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

public_ip() {
  curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null \
    || curl -fsS --max-time 5 https://ifconfig.me 2>/dev/null \
    || hostname -I 2>/dev/null | awk '{print $1}' \
    || echo "<IP-de-la-VM>"
}

show_info() {
  local ip tailscale_ip=""
  ip="$(public_ip)"
  if command -v tailscale >/dev/null 2>&1; then
    tailscale_ip="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
    [[ -n "$tailscale_ip" ]] && ip="$tailscale_ip"
  fi

  # shellcheck disable=SC1090
  . "$ENV_FILE"

  cat <<EOF

============================================================
  Cloudypad est pret 🎮
============================================================

  IP a utiliser    : $ip
  Client           : Moonlight (https://moonlight-stream.org)

  1. Ouvre https://$ip:47990 dans un navigateur
     (certificat self-signe -> accepter l'avertissement)
  2. Connecte-toi avec:
       utilisateur : $SUNSHINE_WEB_USERNAME
       mot de passe: $SUNSHINE_WEB_PASSWORD
  3. Dans Moonlight, ajoute l'hote $ip et lance le pairing.
     Saisis le PIN affiche par Moonlight dans l'UI Sunshine.
     Erreur "CSRF Protection Error" ? lance: bash $0 csrf

  Ports a ouvrir dans le firewall RunPod/Vast:
    TCP  : 22, 47984, 47989, 47990, 48010
    UDP  : 47998, 47999, 48000, 48002

  Arrete la VM depuis le provider quand tu ne joues plus,
  ou utilise: bash $0 stop

  Fichiers: $BASE_DIR
  Logs    : bash $0 logs
============================================================
EOF
}

cmd_csrf() {
  cmd_require_deployed

  local origins="${1:-}"
  if [[ -z "$origins" ]]; then
    if command -v tailscale >/dev/null 2>&1; then
      origins="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
      [[ -n "$origins" ]] && origins="https://${origins}:47990"
    fi
  fi

  [[ -n "$origins" ]] \
    || die "Origine manquante. Exemple: bash $0 csrf https://100.x.y.z:47990"

  sed -i "s#^CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=.*#CLOUDYPAD_SUNSHINE_CSRF_ALLOWED_ORIGINS=${origins}#" "$ENV_FILE"
  log "Origines CSRF autorisees: $origins"
  compose up -d --force-recreate
  log "Attends quelques secondes, puis reessaie le pairing dans Moonlight."
}

cmd_deploy() {
  check_env
  install_docker
  prepare_dirs
  write_env
  write_compose
  log "Telechargement de $IMAGE ..."
  compose pull
  log "Demarrage de $CONTAINER ..."
  compose up -d --remove-orphans
  show_info
}

cmd_require_deployed() {
  [[ -f "$COMPOSE_FILE" && -f "$ENV_FILE" ]] \
    || die "Rien de deploye ici. Lance d'abord: bash $0 deploy"
}

main() {
  local cmd="${1:-deploy}"
  case "$cmd" in
    help|-h|--help)  usage; return 0 ;;
  esac

  need_root "$@"
  case "$cmd" in
    deploy|install)  cmd_deploy ;;
    start)           cmd_require_deployed; compose start "$CONTAINER" ;;
    stop)            cmd_require_deployed; compose stop "$CONTAINER" ;;
    restart)         cmd_require_deployed; compose restart "$CONTAINER" ;;
    status)          cmd_require_deployed; compose ps; echo; nvidia-smi ;;
    logs)            cmd_require_deployed; compose logs -f "$CONTAINER" ;;
    csrf|origin)     cmd_csrf "${2:-}" ;;
    destroy)         cmd_require_deployed; compose down --remove-orphans; log "Container supprime. Donnees conservees dans $BASE_DIR" ;;
    purge)
      cmd_require_deployed
      compose down --remove-orphans
      warn "Suppression de $BASE_DIR (sauvegardes, steam, configs)..."
      rm -rf "$BASE_DIR"
      log "Tout a ete supprime."
      ;;
    *)               die "Commande inconnue: $cmd (voir: bash $0 help)" ;;
  esac
}

main "$@"
