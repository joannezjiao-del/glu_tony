#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-18789}"

BIND_RAW="${OPENCLAW_BIND:-}"
if [ -z "$BIND_RAW" ]; then
  BIND_MODE="lan"
else
  case "$BIND_RAW" in
    0.0.0.0|::) BIND_MODE="lan" ;;
    127.0.0.1|localhost) BIND_MODE="loopback" ;;
    loopback|lan|custom|tailnet|auto) BIND_MODE="$BIND_RAW" ;;
    *)
      echo "[openclaw] unknown OPENCLAW_BIND='$BIND_RAW', falling back to lan"
      BIND_MODE="lan"
      ;;
  esac
fi
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

: "${OPENCLAW_GATEWAY_TOKEN:?Missing OPENCLAW_GATEWAY_TOKEN}"
: "${GEMINI_API_KEY:?Missing GEMINI_API_KEY}"

CONTROL_UI_ORIGIN="${OPENCLAW_CONTROL_UI_ORIGIN:-https://glutony-production.up.railway.app}"
HTTP_CONTROL_UI_ORIGIN="${CONTROL_UI_ORIGIN/https:\/\//http:\/\/}"

if [ ! -f "${STATE_DIR}/openclaw.json" ]; then
  echo "[openclaw] onboarding (first start)..."
  openclaw onboard --non-interactive \
    --mode local \
    --auth-choice gemini-api-key \
    --gemini-api-key "$GEMINI_API_KEY" \
    --secret-input-mode ref \
    --gateway-auth token \
    --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
    --gateway-port "$PORT" \
    --gateway-bind "$BIND_MODE" \
    --skip-health \
    --skip-skills \
    --accept-risk
fi

echo "[openclaw] configuring Control UI allowedOrigins..."
openclaw config set gateway.controlUi.allowedOrigins \
  "[\"${HTTP_CONTROL_UI_ORIGIN}\",\"${CONTROL_UI_ORIGIN}\",\"http://127.0.0.1:${PORT}\",\"http://localhost:${PORT}\"]" \
  --strict-json

echo "[openclaw] configuring trusted proxies for Railway..."
openclaw config set gateway.trustedProxies \
  '["100.64.0.0/10","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]' \
  --strict-json

# Start gateway in background
echo "[openclaw] starting gateway in background..."
openclaw gateway run --bind "$BIND_MODE" --port "$PORT" --verbose &
GATEWAY_PID=$!

# Wait for gateway to be ready, then auto-approve any pending device pairing
echo "[openclaw] waiting for gateway to initialise..."
sleep 10

echo "[openclaw] approving any pending device pairing requests..."
openclaw devices approve --latest 2>&1 || echo "[openclaw] no pending pairing requests (will be approved on first connect)"

echo "[openclaw] printing tokenized dashboard URL..."
openclaw dashboard --no-open 2>&1 || true

echo "[openclaw] gateway is ready!"

# Keep gateway running in foreground
wait $GATEWAY_PID
