#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-18789}"
BIND="${OPENCLAW_BIND:-0.0.0.0}"
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

: "${OPENCLAW_GATEWAY_TOKEN:?Missing OPENCLAW_GATEWAY_TOKEN}"
: "${GEMINI_API_KEY:?Missing GEMINI_API_KEY}"

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
    --gateway-bind "$BIND" \
    --skip-health \
    --skip-skills \
    --accept-risk
fi

echo "[openclaw] starting gateway on ws://${BIND}:${PORT}"
exec openclaw gateway run --bind "$BIND" --port "$PORT" --verbose

