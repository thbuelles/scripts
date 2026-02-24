#!/bin/zsh
set -euo pipefail

raw=$(pmset -g batt)
# Example: -InternalBattery-0	85%; discharging; 3:24 remaining present: true
percent=$(echo "$raw" | awk -F'\t|;| ' '/InternalBattery/{for(i=1;i<=NF;i++) if($i ~ /%/){gsub("%","",$i); print $i; exit}}')
state=$(echo "$raw" | awk -F';' '/InternalBattery/{gsub(/^ +| +$/,"",$2); print $2; exit}')
remaining=$(echo "$raw" | awk -F';' '/InternalBattery/{gsub(/^ +| +$/,"",$3); print $3; exit}' | sed 's/ present:.*$//')

if [[ -z "${percent:-}" ]]; then
  echo "Battery status unavailable"
  exit 1
fi

# Normalize state wording a bit
case "$state" in
  "charging") state_h="charging" ;;
  "discharging") state_h="on battery" ;;
  "finishing charge") state_h="finishing charge" ;;
  *) state_h="$state" ;;
esac

echo "Battery: ${percent}% (${state_h}${remaining:+, ${remaining}})"
