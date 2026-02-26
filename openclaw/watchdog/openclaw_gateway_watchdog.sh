#!/bin/zsh
set -u

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
OPENCLAW_BIN="$(command -v openclaw 2>/dev/null || echo /usr/local/bin/openclaw)"

LOG_DIR="/Users/bici/.openclaw/workspace/logs"
LAST_ALERT_FILE="$LOG_DIR/openclaw-watchdog.last_alert"
EVENT_LOG="$LOG_DIR/openclaw-watchdog.log"
ENV_FILE="/Users/bici/.openclaw/workspace/.secrets/openclaw-watchdog.env"
mkdir -p "$LOG_DIR"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
WHATSAPP_TARGET="${WHATSAPP_TARGET:-}"

now_epoch=$(date +%s)
now_human=$(date '+%Y-%m-%d %H:%M:%S %Z')

status_out=$($OPENCLAW_BIN gateway status 2>&1)
status_rc=$?

is_healthy=0
if [[ $status_rc -eq 0 ]] && echo "$status_out" | grep -qiE 'RPC probe: ok|Gateway:.*reachable|Listening:'; then
  is_healthy=1
fi

if [[ $is_healthy -eq 1 ]]; then
  exit 0
fi

last_alert=0
if [[ -f "$LAST_ALERT_FILE" ]]; then
  last_alert=$(cat "$LAST_ALERT_FILE" 2>/dev/null || echo 0)
fi

# de-dup: alert at most once per 5 minutes for repeated failures
if [[ $last_alert -gt 0 && $((now_epoch - last_alert)) -lt 300 ]]; then
  exit 0
fi

echo "$now_epoch" > "$LAST_ALERT_FILE"

log_file=$(ls -t /tmp/openclaw/openclaw-*.log 2>/dev/null | head -n 1)
err_tail="(no openclaw log file found)"
if [[ -n "${log_file:-}" ]]; then
  err_tail=$(tail -n 80 "$log_file" | tail -n 25)
fi

restart_out=$($OPENCLAW_BIN gateway restart 2>&1)
restart_rc=$?

msg="[openclaw watchdog] gateway unhealthy at $now_human. restart_rc=$restart_rc\nstatus: $(echo "$status_out" | tr '\n' ' ' | cut -c1-280)\nrestart: $(echo "$restart_out" | tr '\n' ' ' | cut -c1-280)\nlog_tail:\n$err_tail"

{
  echo "===== $now_human ====="
  echo "$msg"
  echo
} >> "$EVENT_LOG"

if [[ -n "$WHATSAPP_TARGET" ]]; then
  $OPENCLAW_BIN message send --channel whatsapp --target "$WHATSAPP_TARGET" --message "$msg" >/dev/null 2>&1 || true
fi
