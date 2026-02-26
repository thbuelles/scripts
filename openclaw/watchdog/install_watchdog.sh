#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/bici/.openclaw/workspace"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/openclaw_gateway_watchdog.sh"
SCRIPT_DST="$ROOT/tools/openclaw_gateway_watchdog.sh"
ENV_FILE="$ROOT/.secrets/openclaw-watchdog.env"
LOG_DIR="$ROOT/logs"

mkdir -p "$ROOT/tools" "$ROOT/.secrets" "$LOG_DIR"
cp "$SCRIPT_SRC" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"

if [[ ! -f "$ENV_FILE" ]]; then
  cat > "$ENV_FILE" <<EOF
WHATSAPP_TARGET=+1XXXXXXXXXX
EOF
  chmod 600 "$ENV_FILE"
fi

# Ensure gateway service exists and is running (user service)
openclaw gateway install >/dev/null 2>&1 || true
openclaw gateway start >/dev/null 2>&1 || true

# User agent install (works without sudo)
cp "$(cd "$(dirname "$0")" && pwd)/com.bici.openclaw-gateway-watchdog.agent.plist" "$HOME/Library/LaunchAgents/com.bici.openclaw-gateway-watchdog.plist"
launchctl unload "$HOME/Library/LaunchAgents/com.bici.openclaw-gateway-watchdog.plist" >/dev/null 2>&1 || true
launchctl load -w "$HOME/Library/LaunchAgents/com.bici.openclaw-gateway-watchdog.plist"

echo "User LaunchAgent installed."

echo "To upgrade to system LaunchDaemon (recommended for no-login resilience), run as admin:"
echo "  sudo cp $(cd "$(dirname "$0")" && pwd)/com.bici.openclaw-gateway-watchdog.daemon.plist /Library/LaunchDaemons/com.bici.openclaw-gateway-watchdog.plist"
echo "  sudo chown root:wheel /Library/LaunchDaemons/com.bici.openclaw-gateway-watchdog.plist"
echo "  sudo chmod 644 /Library/LaunchDaemons/com.bici.openclaw-gateway-watchdog.plist"
echo "  sudo launchctl bootstrap system /Library/LaunchDaemons/com.bici.openclaw-gateway-watchdog.plist"
echo "  sudo launchctl enable system/com.bici.openclaw-gateway-watchdog"
echo "  sudo launchctl kickstart -k system/com.bici.openclaw-gateway-watchdog"
