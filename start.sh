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

  # Install the self-improvement skill (pre-cloned in Docker image)
  # Skill name in SKILL.md is "self-improvement"
  SKILLS_DIR="${STATE_DIR}/skills"
  SKILL_DEST="${SKILLS_DIR}/self-improvement"
  SKILL_SRC="/app/skills/self-improving-agent"

  if [ -d "$SKILL_SRC" ] && [ ! -d "$SKILL_DEST" ]; then
    echo "[openclaw] installing skill: self-improvement..."
    mkdir -p "$SKILLS_DIR"
    cp -r "$SKILL_SRC" "$SKILL_DEST"
    echo "[openclaw] skill files copied."
  fi

  if [ -d "$SKILL_DEST" ]; then
    echo "[openclaw] enabling skill: self-improvement..."
    openclaw config set skills.entries.self-improvement.enabled true 2>/dev/null || true
    echo "[openclaw] skill self-improvement is enabled."
  fi

  # Background loop: auto-approve any pending device pairing every 5 seconds
  auto_approve_loop() {
    while true; do
      sleep 5
      openclaw devices approve --latest 2>/dev/null && echo "[openclaw-pairing] approved a pending device" || true
    done
  }
  auto_approve_loop &

  echo "[openclaw] starting gateway (bind mode: ${BIND_MODE}) on port ${PORT}"
  exec openclaw gateway run --bind "$BIND_MODE" --port "$PORT" --verbose
  