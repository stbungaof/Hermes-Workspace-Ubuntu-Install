#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Hermes Agent + Hermes Dashboard + Hermes Workspace
# Ubuntu 24.04 Production Installer
#
# Agent      : NousResearch/hermes-agent
# Workspace  : outsourc-e/hermes-workspace
#
# Services:
#   Hermes Gateway   : 127.0.0.1:8642
#   Hermes Dashboard : 127.0.0.1:9119
#   Workspace        : 0.0.0.0:3000
#
# Remote access:
#   Tailscale / LAN
#
# Security:
#   HERMES_PASSWORD is automatically generated if missing.
#
# No Nginx required.
# ============================================================

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/hermes-workspace}"

GATEWAY_HOST="${GATEWAY_HOST:-127.0.0.1}"
GATEWAY_PORT="${GATEWAY_PORT:-8642}"

DASHBOARD_HOST="${DASHBOARD_HOST:-127.0.0.1}"
DASHBOARD_PORT="${DASHBOARD_PORT:-9119}"
API_SERVER_KEY="6377560380212b377d4dd4ecf00cf90aaa1ca9a9acd593394c20a963d01bb353"
# Workspace must listen on non-loopback for remote access.
WORKSPACE_HOST="${WORKSPACE_HOST:-0.0.0.0}"
WORKSPACE_PORT="${WORKSPACE_PORT:-3000}"

AGENT_INSTALLER="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
WORKSPACE_REPO="https://github.com/outsourc-e/hermes-workspace.git"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

HERMES_ENV="$HERMES_HOME/.env"
WORKSPACE_ENV="$WORKSPACE_DIR/.env"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

die() {
    red ""
    red "ERROR: $*"
    exit 1
}

trap 'red "Installation failed at line $LINENO"' ERR

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

cat <<'EOF'

============================================================
          HERMES AI STACK INSTALLER
============================================================

   Hermes Agent      : NousResearch
   Hermes Gateway    : 127.0.0.1:8642
   Hermes Dashboard  : 127.0.0.1:9119
   Hermes Workspace  : 0.0.0.0:3000

   Remote access     : Tailscale / LAN
   Authentication    : HERMES_PASSWORD
   Init system       : systemd --user

   No Nginx required.

============================================================

EOF

# ------------------------------------------------------------
# OS
# ------------------------------------------------------------

cyan "[1/13] Checking operating system..."

if [[ ! -f /etc/os-release ]]; then
    die "/etc/os-release not found."
fi

source /etc/os-release

green "OS: ${PRETTY_NAME:-unknown}"

# ------------------------------------------------------------
# User
# ------------------------------------------------------------

cyan "[2/13] Checking user..."

if [[ "$EUID" -eq 0 ]]; then
    die "Do not run this installer as root.

Run:

    ./install-hermes.sh

as your normal Linux user."
fi

USER_NAME="$(id -un)"
USER_HOME="$HOME"

green "User: $USER_NAME"
green "Home: $USER_HOME"

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

cyan "[3/13] Installing system dependencies..."

sudo apt-get update

sudo apt-get install -y \
    curl \
    git \
    ca-certificates \
    build-essential \
    python3 \
    python3-venv \
    python3-dev \
    pkg-config \
    libssl-dev \
    libffi-dev \
    ffmpeg \
    ripgrep \
    tmux \
    jq \
    unzip \
    wget \
    openssl

green "System dependencies installed."

# ------------------------------------------------------------
# Node.js 22
# ------------------------------------------------------------

cyan "[4/13] Checking Node.js..."

NODE_MAJOR=0

if command -v node >/dev/null 2>&1; then
    NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
fi

if [[ "$NODE_MAJOR" -lt 22 ]]; then

    yellow "Node.js 22+ required."

    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -

    sudo apt-get install -y nodejs

fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"

if [[ "$NODE_MAJOR" -lt 22 ]]; then
    die "Node.js 22+ installation failed."
fi

green "Node.js: $(node --version)"

# ------------------------------------------------------------
# pnpm
# ------------------------------------------------------------

cyan "[5/13] Checking pnpm..."

if ! command -v pnpm >/dev/null 2>&1; then

    if command -v corepack >/dev/null 2>&1; then
        sudo corepack enable || true
        corepack prepare pnpm@latest --activate || true
    fi

fi

if ! command -v pnpm >/dev/null 2>&1; then
    sudo npm install -g pnpm
fi

PNPM_BIN="$(command -v pnpm)"

green "pnpm: $(pnpm --version)"

# ------------------------------------------------------------
# Hermes Agent
# ------------------------------------------------------------

cyan "[6/13] Installing Hermes Agent..."

export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

if command -v hermes >/dev/null 2>&1; then

    green "Hermes Agent already installed."
    green "Binary: $(command -v hermes)"

else

    yellow "Running official NousResearch installer..."

    curl -fsSL "$AGENT_INSTALLER" | bash

    export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

fi

if ! command -v hermes >/dev/null 2>&1; then
    die "Hermes CLI not found after installation."
fi

HERMES_BIN="$(command -v hermes)"

green "Hermes: $HERMES_BIN"

hermes --version || true

# ------------------------------------------------------------
# Hermes directories
# ------------------------------------------------------------

cyan "[7/13] Preparing Hermes directories..."

mkdir -p "$HERMES_HOME"
mkdir -p "$HERMES_HOME/skills"
mkdir -p "$HERMES_HOME/logs"
mkdir -p "$SYSTEMD_USER_DIR"

touch "$HERMES_ENV"

chmod 700 "$HERMES_HOME"
chmod 600 "$HERMES_ENV"

# ------------------------------------------------------------
# Helper
# ------------------------------------------------------------

set_env() {

    local file="$1"
    local key="$2"
    local value="$3"

    touch "$file"

    if grep -qE "^${key}=" "$file"; then

        sed -i \
            "s|^${key}=.*|${key}=${value}|" \
            "$file"

    else

        printf '%s=%s\n' "$key" "$value" >> "$file"

    fi
}

# ------------------------------------------------------------
# Hermes API configuration
# ------------------------------------------------------------

cyan "[8/13] Configuring Hermes API..."

set_env "$HERMES_ENV" \
    "API_SERVER_ENABLED" \
    "true"

set_env "$HERMES_ENV" \
    "API_SERVER_KEY" \
    "$API_SERVER_KEY"

set_env "$HERMES_ENV" \
    "API_SERVER_HOST" \
    "$GATEWAY_HOST"

set_env "$HERMES_ENV" \
    "API_SERVER_PORT" \
    "$GATEWAY_PORT"

# Allow all gateway users.
# Workspace authentication and Tailscale/LAN access remain responsible
# for protecting the remote control plane.
set_env "$HERMES_ENV" \
    "GATEWAY_ALLOW_ALL_USERS" \
    "true"

green "Hermes API configured."

# ------------------------------------------------------------
# Workspace clone
# ------------------------------------------------------------

cyan "[9/13] Installing Hermes Workspace..."

if [[ -d "$WORKSPACE_DIR/.git" ]]; then

    yellow "Workspace already exists."

    git -C "$WORKSPACE_DIR" fetch origin
    git -C "$WORKSPACE_DIR" pull --ff-only

else

    git clone "$WORKSPACE_REPO" "$WORKSPACE_DIR"

fi

cd "$WORKSPACE_DIR"

green "Workspace: $WORKSPACE_DIR"

# ------------------------------------------------------------
# Workspace .env
# ------------------------------------------------------------

if [[ ! -f "$WORKSPACE_ENV" ]]; then

    if [[ -f ".env.example" ]]; then
        cp ".env.example" "$WORKSPACE_ENV"
    else
        touch "$WORKSPACE_ENV"
    fi

fi

set_env "$WORKSPACE_ENV" \
    "HERMES_API_URL" \
    "http://${GATEWAY_HOST}:${GATEWAY_PORT}"

set_env "$WORKSPACE_ENV" \
    "HERMES_DASHBOARD_URL" \
    "http://${DASHBOARD_HOST}:${DASHBOARD_PORT}"

set_env "$WORKSPACE_ENV" \
    "HOST" \
    "$WORKSPACE_HOST"

set_env "$WORKSPACE_ENV" \
    "PORT" \
    "$WORKSPACE_PORT"

set_env "$WORKSPACE_ENV" \
    "NODE_ENV" \
    "production"

set_env "$WORKSPACE_ENV" \
    "HERMES_API_TOKEN" \
    "$API_SERVER_KEY"
# Workspace is exposed over HTTP on LAN/Tailscale.
# Disable the Secure cookie flag because browsers reject Secure cookies
# when the site is accessed over plain HTTP.
set_env "$WORKSPACE_ENV" \
    "COOKIE_SECURE" \
    "0"

chmod 600 "$WORKSPACE_ENV"

# ------------------------------------------------------------
# Workspace password
# ------------------------------------------------------------

cyan "[10/13] Configuring Workspace authentication..."

# Priority:
#
# 1. Existing HERMES_PASSWORD in .env
# 2. Existing password from environment
# 3. Generate new password
#

EXISTING_PASSWORD=""

if [[ -f "$WORKSPACE_ENV" ]]; then

    EXISTING_PASSWORD="$(
        grep '^HERMES_PASSWORD=' "$WORKSPACE_ENV" \
        | head -1 \
        | cut -d= -f2- \
        || true
    )"

fi

if [[ -n "$EXISTING_PASSWORD" ]]; then

    HERMES_PASSWORD="$EXISTING_PASSWORD"

    green "Existing HERMES_PASSWORD found. Keeping existing password."

elif [[ -n "${HERMES_PASSWORD:-}" ]]; then

    green "Using HERMES_PASSWORD from environment."

else

    HERMES_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"

    green "Generated a new secure Workspace password."

fi

# Store password in Workspace .env
set_env "$WORKSPACE_ENV" \
    "HERMES_PASSWORD" \
    "$HERMES_PASSWORD"

chmod 600 "$WORKSPACE_ENV"

# Also keep password in a private credentials file.
CREDENTIALS_FILE="$HERMES_HOME/workspace-password"

printf '%s\n' "$HERMES_PASSWORD" > "$CREDENTIALS_FILE"

chmod 600 "$CREDENTIALS_FILE"

green "Workspace authentication configured."

# ------------------------------------------------------------
# Install dependencies
# ------------------------------------------------------------

cyan "[11/13] Installing Workspace dependencies..."

cd "$WORKSPACE_DIR"

pnpm install

green "Dependencies installed."

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

cyan "Building Workspace..."

pnpm build

green "Workspace build completed."

# ------------------------------------------------------------
# systemd
# ------------------------------------------------------------

cyan "[12/13] Creating systemd services..."

sudo loginctl enable-linger "$USER_NAME" || true

# ------------------------------------------------------------
# Gateway service
# ------------------------------------------------------------

cat > "$SYSTEMD_USER_DIR/hermes-gateway.service" <<EOF
[Unit]
Description=Hermes Agent Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment=HOME=$HOME
Environment=HERMES_HOME=$HERMES_HOME
Environment=PATH=$HOME/.hermes/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-$HERMES_ENV

WorkingDirectory=$HERMES_HOME

ExecStart=$HERMES_BIN gateway run

Restart=always
RestartSec=5

KillMode=mixed
TimeoutStopSec=30

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# ------------------------------------------------------------
# Dashboard service
# ------------------------------------------------------------

cat > "$SYSTEMD_USER_DIR/hermes-dashboard.service" <<EOF
[Unit]
Description=Hermes Agent Dashboard
After=hermes-gateway.service network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment=HOME=$HOME
Environment=HERMES_HOME=$HERMES_HOME
Environment=PATH=$HOME/.hermes/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin

WorkingDirectory=$HERMES_HOME

ExecStart=$HERMES_BIN dashboard --host $DASHBOARD_HOST --port $DASHBOARD_PORT

Restart=always
RestartSec=5

KillMode=mixed
TimeoutStopSec=30

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# ------------------------------------------------------------
# Workspace service
# ------------------------------------------------------------

cat > "$SYSTEMD_USER_DIR/hermes-workspace.service" <<EOF
[Unit]
Description=Hermes Workspace
After=hermes-gateway.service hermes-dashboard.service network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment=HOME=$HOME
Environment=NODE_ENV=production

# Remote access
Environment=HOST=$WORKSPACE_HOST
Environment=PORT=$WORKSPACE_PORT

# Backend services remain localhost
Environment=HERMES_API_URL=http://$GATEWAY_HOST:$GATEWAY_PORT
Environment=HERMES_DASHBOARD_URL=http://$DASHBOARD_HOST:$DASHBOARD_PORT
Environment=HERMES_API_TOKEN=$API_SERVER_KEY

# Workspace authentication
Environment=HERMES_PASSWORD=$HERMES_PASSWORD

WorkingDirectory=$WORKSPACE_DIR

ExecStart=$PNPM_BIN start

Restart=always
RestartSec=5

KillMode=mixed
TimeoutStopSec=30

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

chmod 600 "$SYSTEMD_USER_DIR/hermes-gateway.service"
chmod 600 "$SYSTEMD_USER_DIR/hermes-dashboard.service"
chmod 600 "$SYSTEMD_USER_DIR/hermes-workspace.service"

# ------------------------------------------------------------
# Reload
# ------------------------------------------------------------

systemctl --user daemon-reload

# ------------------------------------------------------------
# Stop existing services
# ------------------------------------------------------------

systemctl --user stop hermes-workspace.service 2>/dev/null || true
systemctl --user stop hermes-dashboard.service 2>/dev/null || true
systemctl --user stop hermes-gateway.service 2>/dev/null || true

# ------------------------------------------------------------
# Enable
# ------------------------------------------------------------

systemctl --user enable hermes-gateway.service
systemctl --user enable hermes-dashboard.service
systemctl --user enable hermes-workspace.service

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

cyan "[13/13] Starting Hermes services..."

systemctl --user start hermes-gateway.service

sleep 10

systemctl --user start hermes-dashboard.service

sleep 10

systemctl --user start hermes-workspace.service

sleep 10

# ------------------------------------------------------------
# Health checks
# ------------------------------------------------------------

echo
bold "============================================================"
bold "                    HEALTH CHECK"
bold "============================================================"

echo

# Gateway
if curl -fsS \
    --connect-timeout 5 \
    "http://${GATEWAY_HOST}:${GATEWAY_PORT}/health" \
    >/tmp/hermes-gateway-health.json 2>/dev/null; then

    green "Gateway     : OK"

else

    yellow "Gateway     : FAILED"

fi

# Dashboard
if curl -fsS \
    --connect-timeout 5 \
    "http://${DASHBOARD_HOST}:${DASHBOARD_PORT}/api/status" \
    >/tmp/hermes-dashboard-health.json 2>/dev/null; then

    green "Dashboard   : OK"

else

    yellow "Dashboard   : FAILED"

fi

# Workspace
if curl -fsS \
    --connect-timeout 5 \
    "http://127.0.0.1:${WORKSPACE_PORT}" \
    >/dev/null 2>&1; then

    green "Workspace   : OK"

else

    yellow "Workspace   : FAILED"

fi

# ------------------------------------------------------------
# Ports
# ------------------------------------------------------------

echo
bold "Listening ports:"
echo

ss -lntp 2>/dev/null \
    | grep -E ":${GATEWAY_PORT}|:${DASHBOARD_PORT}|:${WORKSPACE_PORT}" \
    || true

# ------------------------------------------------------------
# Tailscale detection
# ------------------------------------------------------------

echo
bold "Tailscale:"
echo

if command -v tailscale >/dev/null 2>&1; then

    TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"

    if [[ -n "$TAILSCALE_IP" ]]; then

        green "Tailscale IP: $TAILSCALE_IP"

        echo
        echo "Workspace URL:"
        echo
        echo "  http://${TAILSCALE_IP}:${WORKSPACE_PORT}"

    else

        yellow "Tailscale installed but no IP detected."

    fi

else

    yellow "Tailscale is not installed."

    echo
    echo "Install with:"
    echo
    echo "  curl -fsSL https://tailscale.com/install.sh | sh"
    echo "  sudo tailscale up"

fi

# ------------------------------------------------------------
# Password
# ------------------------------------------------------------

echo
bold "============================================================"
bold "             WORKSPACE CREDENTIALS"
bold "============================================================"

echo
echo "Password is stored securely at:"
echo
echo "  $CREDENTIALS_FILE"
echo
echo "Show password:"
echo
echo "  cat $CREDENTIALS_FILE"
echo

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------

bold "============================================================"
bold "              HERMES INSTALLATION COMPLETE"
bold "============================================================"

echo

echo "Services:"
echo
echo "  Gateway:"
echo "    http://${GATEWAY_HOST}:${GATEWAY_PORT}"
echo
echo "  Dashboard:"
echo "    http://${DASHBOARD_HOST}:${DASHBOARD_PORT}"
echo
echo "  Workspace:"
echo "    http://${WORKSPACE_HOST}:${WORKSPACE_PORT}"
echo

echo "Workspace directory:"
echo
echo "  $WORKSPACE_DIR"
echo

echo "Hermes directory:"
echo
echo "  $HERMES_HOME"
echo

echo "Systemd status:"
echo
echo "  systemctl --user status hermes-gateway"
echo "  systemctl --user status hermes-dashboard"
echo "  systemctl --user status hermes-workspace"
echo

echo "Logs:"
echo
echo "  journalctl --user -u hermes-gateway -f"
echo "  journalctl --user -u hermes-dashboard -f"
echo "  journalctl --user -u hermes-workspace -f"
echo

echo "Remote access:"
echo
echo "  Use the Tailscale IP + :3000"
echo

green "Hermes is ready."
echo