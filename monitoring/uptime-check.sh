#!/usr/bin/env bash
# Sonde a placer en tache cron toutes les 5 minutes.
# Alerte apres trois echecs consecutifs pour eviter le bruit.
set -euo pipefail
URL="${HEALTHCHECK_URL:?}"
STATE="/tmp/uptime-failures"
WEBHOOK="${ALERT_WEBHOOK:-}"

code=$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$URL" || echo "000")
if [ "$code" = "200" ]; then
  [ -f "$STATE" ] && [ "$(cat "$STATE")" -ge 3 ] && \
    curl -s -X POST "$WEBHOOK" -H 'Content-Type: application/json' \
      -d "{\"content\":\"Service retabli : ${URL}\"}" > /dev/null
  echo 0 > "$STATE"
  exit 0
fi

n=$(( $(cat "$STATE" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$STATE"
if [ "$n" -eq 3 ] && [ -n "$WEBHOOK" ]; then
  curl -s -X POST "$WEBHOOK" -H 'Content-Type: application/json' \
    -d "{\"content\":\"Alerte : ${URL} injoignable depuis 15 minutes. Dernier code HTTP ${code}.\"}" > /dev/null
fi
exit 1
