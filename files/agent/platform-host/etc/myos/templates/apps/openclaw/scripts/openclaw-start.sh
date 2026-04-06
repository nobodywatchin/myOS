#!/bin/sh
set -eu

cd /app

export HOME="${HOME:-/home/node}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_STATE_DIR}/openclaw.json}"
mkdir -p "${OPENCLAW_STATE_DIR}" "${OPENCLAW_STATE_DIR}/workspace" /tmp/openclaw

ui_pid=""
gateway_pid=""

cleanup() {
  status=${1:-0}

  if [ -n "${ui_pid}" ] && kill -0 "${ui_pid}" 2>/dev/null; then
    kill "${ui_pid}" 2>/dev/null || true
  fi
  if [ -n "${gateway_pid}" ] && kill -0 "${gateway_pid}" 2>/dev/null; then
    kill "${gateway_pid}" 2>/dev/null || true
  fi

  wait "${ui_pid}" 2>/dev/null || true
  wait "${gateway_pid}" 2>/dev/null || true
  exit "${status}"
}

trap 'cleanup 143' TERM INT HUP

node /tmp/openclaw-ui-server.mjs &
ui_pid=$!

node openclaw.mjs gateway &
gateway_pid=$!

while :; do
  if ! kill -0 "${ui_pid}" 2>/dev/null; then
    wait "${ui_pid}"
    cleanup "$?"
  fi

  if ! kill -0 "${gateway_pid}" 2>/dev/null; then
    wait "${gateway_pid}"
    cleanup "$?"
  fi

  sleep 1
done
