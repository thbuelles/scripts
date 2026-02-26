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

strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

status_out=$($OPENCLAW_BIN gateway status 2>&1 | strip_ansi)
status_rc=$?

is_healthy=0
if [[ $status_rc -eq 0 ]] && echo "$status_out" | grep -qiE 'RPC probe: ok|Listening: 127\.0\.0\.1:18789|Listening:'; then
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

status_summary=$(echo "$status_out" | grep -E 'Service:|Runtime:|RPC probe:|Listening:|Dashboard:' | head -n 6)
if [[ -z "$status_summary" ]]; then
  status_summary="(no concise status lines found)"
fi

log_file=$(ls -t /tmp/openclaw/openclaw-*.log 2>/dev/null | head -n 1)
err_tail="(no openclaw log file found)"
if [[ -n "${log_file:-}" ]]; then
  err_tail=$(tail -n 120 "$log_file" | grep -v '^{' | tail -n 20)
  [[ -z "$err_tail" ]] && err_tail="(log tail had only structured JSON lines)"
fi

incident_id=$(date +%s)

restart_out=$($OPENCLAW_BIN gateway restart 2>&1 | strip_ansi)
restart_rc=$?
restart_summary=$(echo "$restart_out" | grep -E 'Service:|Runtime:|RPC probe:|Listening:|Gateway:' | head -n 6)
[[ -z "$restart_summary" ]] && restart_summary="(no concise restart lines found)"

# Wait for recovery (up to ~30s)
recovered=0
for _ in {1..10}; do
  sleep 3
  probe_out=$($OPENCLAW_BIN gateway status 2>&1 | strip_ansi)
  if echo "$probe_out" | grep -qiE 'RPC probe: ok|Listening: 127\.0\.0\.1:18789|Listening:'; then
    recovered=1
    break
  fi
done

crash_msg="[openclaw watchdog][$incident_id] crash detected at $now_human\nstatus_summary:\n$status_summary\nlog_tail:\n$err_tail"
recover_msg="[openclaw watchdog][$incident_id] restart attempted (rc=$restart_rc), recovered=$recovered\nrestart_summary:\n$restart_summary"

{
  echo "===== $now_human ====="
  echo "$crash_msg"
  echo "$recover_msg"
  echo
} >> "$EVENT_LOG"

if [[ -n "$WHATSAPP_TARGET" ]]; then
  # Send crash + recovery notifications with retry after gateway comes back
  for _ in {1..5}; do
    $OPENCLAW_BIN message send --channel whatsapp --target "$WHATSAPP_TARGET" --message "$crash_msg" >/dev/null 2>&1 && break
    sleep 2
  done
  for _ in {1..5}; do
    $OPENCLAW_BIN message send --channel whatsapp --target "$WHATSAPP_TARGET" --message "$recover_msg" >/dev/null 2>&1 && break
    sleep 2
  done
fi
