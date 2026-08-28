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
#   Workspace        : 127.0.0.1:3000
#
# No Nginx required.
# ============================================================

export DEBIAN_FRONTEND=noninteractive

# -----------------------------
# Configuration
# -----------------------------

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/hermes-workspace}"

GATEWAY_HOST="${GATEWAY_HOST:-127.0.0.1}"
GATEWAY_PORT="${GATEWAY_PORT:-8642}"

DASHBOARD_HOST="${DASHBOARD_HOST:-127.0.0.1}"
DASHBOARD_PORT="${DASHBOARD_PORT:-9119}"

WORKSPACE_HOST="${WORKSPACE_HOST:-0.0.0.0}"
WORKSPACE_PORT="${WORKSPACE_PORT:-3000}"

AGENT_REPO="https://github.com/NousResearch/hermes-agent.git"
WORKSPACE_REPO="https://github.com/outsourc-e/hermes-workspace.git"

AGENT_INSTALLER="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# -----------------------------
# Colors
# -----------------------------

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

# -----------------------------
# Trap
# -----------------------------

trap 'red "Installation failed at line $LINENO"' ERR

# -----------------------------
# Banner
# -----------------------------

clear 2>/dev/null || true

cat <<'EOF'

============================================================
          HERMES AI STACK INSTALLER
============================================================

   Hermes Agent      : NousResearch
   Hermes Dashboard  : API :9119
   Hermes Gateway    : API :8642
   Hermes Workspace  : Web :3000

   Ubuntu 24.04
   systemd
   No Nginx
   Production mode

============================================================

EOF

# -----------------------------
# Check OS
# -----------------------------

cyan "[1/12] Checking operating system..."

if [[ ! -f /etc/os-release ]]; then
    die "/etc/os-release not found"
fi

source /etc/os-release

if [[ "$ID" != "ubuntu" ]]; then
    yellow "Warning: This script was designed for Ubuntu."
fi

green "OS: ${PRETTY_NAME:-unknown}"

# -----------------------------
# Check user
# -----------------------------

cyan "[2/12] Checking user..."

if [[ "$EUID" -eq 0 ]]; then
    die "Do NOT run this script as root.

Run:

  bash install-hermes.sh

as your normal user.

The script uses ~/.hermes and systemd --user."
fi

USER_NAME="$(id -un)"
USER_HOME="$HOME"

green "User: $USER_NAME"
green "Home: $USER_HOME"

# -----------------------------
# Install OS dependencies
# -----------------------------

cyan "[3/12] Installing system dependencies..."

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
    wget

green "System dependencies installed."

# -----------------------------
# Node.js 22
# -----------------------------

cyan "[4/12] Installing / checking Node.js..."

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

# -----------------------------
# pnpm
# -----------------------------

cyan "[5/12] Installing pnpm..."

if ! command -v pnpm >/dev/null 2>&1; then

    if command -v corepack >/dev/null 2>&1; then
        sudo corepack enable || true
        corepack prepare pnpm@latest --activate || true
    fi
fi

if ! command -v pnpm >/dev/null 2>&1; then
    sudo npm install -g pnpm
fi

green "pnpm: $(pnpm --version)"

# -----------------------------
# Hermes Agent
# -----------------------------

cyan "[6/12] Installing Hermes Agent..."

export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

if command -v hermes >/dev/null 2>&1; then

    green "Hermes already installed."
    green "Binary: $(command -v hermes)"

else

    yellow "Running official NousResearch installer..."

    curl -fsSL "$AGENT_INSTALLER" | bash

    export PATH="$HOME/.hermes/bin:$HOME/.local/bin:$PATH"

fi

if ! command -v hermes >/dev/null 2>&1; then
    die "Hermes CLI was not found after installation."
fi

HERMES_BIN="$(command -v hermes)"

green "Hermes: $HERMES_BIN"

hermes --version || true

# -----------------------------
# Hermes directories
# -----------------------------

cyan "[7/12] Preparing Hermes directories..."

mkdir -p "$HERMES_HOME"
mkdir -p "$HERMES_HOME/skills"
mkdir -p "$HERMES_HOME/logs"
mkdir -p "$SYSTEMD_USER_DIR"

# Hermes environment file
HERMES_ENV="$HERMES_HOME/.env"

touch "$HERMES_ENV"

chmod 700 "$HERMES_HOME"
chmod 600 "$HERMES_ENV"

# -----------------------------
# Helper: set env
# -----------------------------

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

# -----------------------------
# Hermes API configuration
# -----------------------------

cyan "[8/12] Configuring Hermes API..."

set_env "$HERMES_ENV" \
    "API_SERVER_ENABLED" \
    "true"

set_env "$HERMES_ENV" \
    "API_SERVER_HOST" \
    "$GATEWAY_HOST"

set_env "$HERMES_ENV" \
    "API_SERVER_PORT" \
    "$GATEWAY_PORT"

green "Hermes API configuration:"
grep -E '^API_SERVER_' "$HERMES_ENV" || true

# -----------------------------
# Workspace clone/update
# -----------------------------

cyan "[9/12] Installing Hermes Workspace..."

if [[ -d "$WORKSPACE_DIR/.git" ]]; then

    yellow "Workspace already exists."

    git -C "$WORKSPACE_DIR" fetch origin
    git -C "$WORKSPACE_DIR" pull --ff-only

else

    git clone "$WORKSPACE_REPO" "$WORKSPACE_DIR"

fi

cd "$WORKSPACE_DIR"

green "Workspace: $WORKSPACE_DIR"

# -----------------------------
# Workspace ENV
# -----------------------------

if [[ ! -f "$WORKSPACE_DIR/.env" ]]; then

    if [[ -f "$WORKSPACE_DIR/.env.example" ]]; then
        cp "$WORKSPACE_DIR/.env.example" "$WORKSPACE_DIR/.env"
    else
        touch "$WORKSPACE_DIR/.env"
    fi

fi

set_env "$WORKSPACE_DIR/.env" \
    "HERMES_API_URL" \
    "http://${GATEWAY_HOST}:${GATEWAY_PORT}"

set_env "$WORKSPACE_DIR/.env" \
    "HERMES_DASHBOARD_URL" \
    "http://${DASHBOARD_HOST}:${DASHBOARD_PORT}"

set_env "$WORKSPACE_DIR/.env" \
    "HOST" \
    "$WORKSPACE_HOST"

set_env "$WORKSPACE_DIR/.env" \
    "PORT" \
    "$WORKSPACE_PORT"

set_env "$WORKSPACE_DIR/.env" \
    "NODE_ENV" \
    "production"

chmod 600 "$WORKSPACE_DIR/.env"

# -----------------------------
# Install workspace dependencies
# -----------------------------

cyan "Installing Workspace dependencies..."

pnpm install

# -----------------------------
# Build Workspace
# -----------------------------

cyan "Building Hermes Workspace..."

pnpm build

green "Workspace build completed."

# -----------------------------
# systemd user environment
# -----------------------------

cyan "[10/12] Configuring systemd user services..."

# Ensure systemd user services survive logout/reboot
sudo loginctl enable-linger "$USER_NAME" || true

# ------------------------------------------------
# Hermes Gateway
# ------------------------------------------------

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

# ------------------------------------------------
# Hermes Dashboard
# ------------------------------------------------

cat > "$SYSTEMD_USER_DIR/hermes-dashboard.service" <<EOF
[Unit]
Description=Hermes Agent Dashboard API
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

# ------------------------------------------------
# Hermes Workspace
# ------------------------------------------------

PNPM_BIN="$(command -v pnpm)"

cat > "$SYSTEMD_USER_DIR/hermes-workspace.service" <<EOF
[Unit]
Description=Hermes Workspace
After=hermes-gateway.service hermes-dashboard.service network-online.target
Wants=network-online.target

[Service]
Type=simple

Environment=HOME=$HOME
Environment=NODE_ENV=production
Environment=HOST=$WORKSPACE_HOST
Environment=PORT=$WORKSPACE_PORT

Environment=HERMES_API_URL=http://$GATEWAY_HOST:$GATEWAY_PORT
Environment=HERMES_DASHBOARD_URL=http://$DASHBOARD_HOST:$DASHBOARD_PORT

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

chmod 644 "$SYSTEMD_USER_DIR/hermes-gateway.service"
chmod 644 "$SYSTEMD_USER_DIR/hermes-dashboard.service"
chmod 644 "$SYSTEMD_USER_DIR/hermes-workspace.service"

# -----------------------------
# Reload systemd
# -----------------------------

systemctl --user daemon-reload

# -----------------------------
# Stop old services
# -----------------------------

cyan "[11/12] Restarting Hermes services..."

systemctl --user stop hermes-workspace.service 2>/dev/null || true
systemctl --user stop hermes-dashboard.service 2>/dev/null || true
systemctl --user stop hermes-gateway.service 2>/dev/null || true

# -----------------------------
# Enable services
# -----------------------------

systemctl --user enable hermes-gateway.service
systemctl --user enable hermes-dashboard.service
systemctl --user enable hermes-workspace.service

# -----------------------------
# Start
# -----------------------------

systemctl --user start hermes-gateway.service

sleep 3

systemctl --user start hermes-dashboard.service

sleep 3

systemctl --user start hermes-workspace.service

sleep 5

# -----------------------------
# Health check
# -----------------------------

cyan "[12/12] Running health checks..."

echo
echo "------------------------------------------------------------"
echo "Hermes Gateway"
echo "------------------------------------------------------------"

if curl -fsS \
    --connect-timeout 5 \
    "http://${GATEWAY_HOST}:${GATEWAY_PORT}/health" \
    >/tmp/hermes-gateway-health.json 2>/dev/null; then

    green "Gateway: OK"

    cat /tmp/hermes-gateway-health.json
    echo

else

    yellow "Gateway health check failed."

    systemctl --user status hermes-gateway.service \
        --no-pager || true

fi

echo
echo "------------------------------------------------------------"
echo "Hermes Dashboard"
echo "------------------------------------------------------------"

if curl -fsS \
    --connect-timeout 5 \
    "http://${DASHBOARD_HOST}:${DASHBOARD_PORT}/api/status" \
    >/tmp/hermes-dashboard-health.json 2>/dev/null; then

    green "Dashboard: OK"

    cat /tmp/hermes-dashboard-health.json
    echo

else

    yellow "Dashboard API check failed."

    systemctl --user status hermes-dashboard.service \
        --no-pager || true

fi

echo
echo "------------------------------------------------------------"
echo "Hermes Workspace"
echo "------------------------------------------------------------"

if curl -fsS \
    --connect-timeout 5 \
    "http://${WORKSPACE_HOST}:${WORKSPACE_PORT}" \
    >/dev/null 2>&1; then

    green "Workspace: OK"

else

    yellow "Workspace HTTP check failed."

    systemctl --user status hermes-workspace.service \
        --no-pager || true

fi

# -----------------------------
# Service status
# -----------------------------

echo
bold "============================================================"
bold "             HERMES INSTALLATION COMPLETE"
bold "============================================================"

echo

echo "Services:"
echo
echo "  Hermes Gateway"
echo "    http://${GATEWAY_HOST}:${GATEWAY_PORT}"
echo
echo "  Hermes Dashboard"
echo "    http://${DASHBOARD_HOST}:${DASHBOARD_PORT}"
echo
echo "  Hermes Workspace"
echo "    http://${WORKSPACE_HOST}:${WORKSPACE_PORT}"
echo

echo "Installation:"
echo
echo "  Hermes Home:"
echo "    $HERMES_HOME"
echo
echo "  Workspace:"
echo "    $WORKSPACE_DIR"
echo

echo "Systemd:"
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

echo "Restart all:"
echo
echo "  systemctl --user restart hermes-gateway"
echo "  systemctl --user restart hermes-dashboard"
echo "  systemctl --user restart hermes-workspace"
echo

echo "Status:"
echo
systemctl --user --no-pager --type=service \
    | grep -E 'hermes-(gateway|dashboard|workspace)' \
    || true

echo
green "Hermes is ready."
echo