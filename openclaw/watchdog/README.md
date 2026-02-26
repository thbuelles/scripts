# OpenClaw Gateway Watchdog

Restarts OpenClaw gateway when unhealthy, logs crash context, and alerts WhatsApp.

## Files
- `openclaw_gateway_watchdog.sh` — health check + restart + notify logic (60s cadence)
- `com.bici.openclaw-gateway-watchdog.agent.plist` — user LaunchAgent
- `com.bici.openclaw-gateway-watchdog.daemon.plist` — system LaunchDaemon (more robust)
- `install_watchdog.sh` — installer and setup helper

## Alert target
Set in:
`/Users/bici/.openclaw/workspace/.secrets/openclaw-watchdog.env`

```bash
WHATSAPP_TARGET=+1XXXXXXXXXX
```

## Logs
- `/Users/bici/.openclaw/workspace/logs/openclaw-watchdog.log`
- `/Users/bici/.openclaw/workspace/logs/openclaw-watchdog.stdout.log`
- `/Users/bici/.openclaw/workspace/logs/openclaw-watchdog.stderr.log`
