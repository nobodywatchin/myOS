#!/bin/sh
set -eu

cleanup() {
  kill "${gateway_pid:-}" "${ui_pid:-}" 2>/dev/null || true
  wait "${gateway_pid:-0}" 2>/dev/null || true
  wait "${ui_pid:-0}" 2>/dev/null || true
}

trap 'cleanup; exit 0' INT TERM HUP

cd /app

export HOME="${HOME:-/home/node}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_STATE_DIR}/openclaw.json}"
mkdir -p "${OPENCLAW_STATE_DIR}" "${OPENCLAW_STATE_DIR}/workspace" /tmp/openclaw

node openclaw.mjs gateway --allow-unconfigured &
gateway_pid=$!

node /tmp/openclaw-ui-server.mjs &
ui_pid=$!

while kill -0 "$gateway_pid" 2>/dev/null && kill -0 "$ui_pid" 2>/dev/null; do
  sleep 1
done

status=1

if ! kill -0 "$gateway_pid" 2>/dev/null; then
  wait "$gateway_pid" || status=$?
fi

if ! kill -0 "$ui_pid" 2>/dev/null; then
  wait "$ui_pid" || status=$?
fi

cleanup
exit "$status"
