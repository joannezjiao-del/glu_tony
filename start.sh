#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-18789}"
#
# OpenClaw 现在要求 gateway.bind 使用“bind modes”
# 例如：loopback/lan/custom/tailnet/auto，而不是 0.0.0.0 这种 legacy host alias。
#
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

# Control UI 的跨域来源白名单（origin 需要包含协议 https://...）
# 如果你的 Railway 域名不是默认的那个，可以在 Railway Variables 里额外设置：
# OPENCLAW_CONTROL_UI_ORIGIN=https://your-domain.up.railway.app
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
# Set before starting the gateway so it doesn't reject the browser origin.
openclaw config set gateway.controlUi.allowedOrigins \
  "[\"${HTTP_CONTROL_UI_ORIGIN}\",\"${CONTROL_UI_ORIGIN}\",\"http://127.0.0.1:${PORT}\",\"http://localhost:${PORT}\"]" \
  --strict-json

echo "[openclaw] starting gateway (bind mode: ${BIND_MODE}) on port ${PORT}"
exec openclaw gateway run --bind "$BIND_MODE" --port "$PORT" --verbose

