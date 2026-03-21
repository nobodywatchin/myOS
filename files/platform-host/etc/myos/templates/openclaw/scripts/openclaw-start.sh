#!/bin/sh
set -eu

cd /app

export HOME="${HOME:-/home/node}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${OPENCLAW_STATE_DIR}/openclaw.json}"
mkdir -p "${OPENCLAW_STATE_DIR}" "${OPENCLAW_STATE_DIR}/workspace" /tmp/openclaw

exec node openclaw.mjs gateway
