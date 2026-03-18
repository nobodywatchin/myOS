#!/usr/bin/env bash
set -Eeuo pipefail

MYOS_ETC="${MYOS_ETC:-/etc/myos}"
TENANT_BASE="${TENANT_BASE:-/srv/tenants}"
TEMPLATE_BASE="${TEMPLATE_BASE:-${MYOS_ETC}/templates/openclaw}"
PORT_STATE_FILE="${PORT_STATE_FILE:-${MYOS_ETC}/tenants/ports.state}"
PORT_LOCK_DIR="${PORT_LOCK_DIR:-/run/myos-port-allocate.lock}"

log() {
  printf '[myos] %s\n' "$*"
}

warn() {
  printf '[myos] WARN: %s\n' "$*" >&2
}

die() {
  printf '[myos] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "run as root"
}

validate_tenant() {
  local tenant="${1:-}"

  [[ -n "$tenant" ]] || die "tenant name is required"
  [[ "$tenant" =~ ^[a-z][a-z0-9-]{1,31}$ ]] || die "tenant names must match ^[a-z][a-z0-9-]{1,31}$"
}

tenant_root() {
  printf '%s/%s\n' "$TENANT_BASE" "$1"
}

tenant_home() {
  printf '%s/home\n' "$(tenant_root "$1")"
}

tenant_config_root() {
  printf '%s/config\n' "$(tenant_root "$1")"
}

tenant_env_dir() {
  printf '%s/env\n' "$(tenant_config_root "$1")"
}

tenant_secret_dir() {
  printf '%s/zone-c/secrets\n' "$(tenant_root "$1")"
}

tenant_state_dir() {
  printf '%s/zone-c/state\n' "$(tenant_root "$1")"
}

ensure_dir() {
  local mode="$1"
  local owner="$2"
  local group="$3"
  local path="$4"

  install -d -m "$mode" -o "$owner" -g "$group" "$path"
}

ensure_user() {
  local tenant="$1"
  local home

  install -d -m 0755 "$TENANT_BASE"
  home="$(tenant_home "$tenant")"

  if ! getent passwd "$tenant" >/dev/null 2>&1; then
    useradd \
      --create-home \
      --home-dir "$home" \
      --shell /usr/sbin/nologin \
      --comment "myOS OpenClaw tenant ${tenant}" \
      "$tenant"
  fi

  ensure_dir 0750 "$tenant" "$tenant" "$home"
}

next_subid_start() {
  local file="$1"

  awk -F: -v default=200000 '
    BEGIN { max = default }
    NF >= 3 && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
      end = $2 + $3
      if (end > max) {
        max = end
      }
    }
    END { print max + 1 }
  ' "$file" 2>/dev/null
}

ensure_subid_range() {
  local file="$1"
  local name="$2"
  local count="${3:-65536}"
  local start

  if grep -q "^${name}:" "$file" 2>/dev/null; then
    return 0
  fi

  start="$(next_subid_start "$file")"
  printf '%s:%s:%s\n' "$name" "${start:-200001}" "$count" >> "$file"
}

escape_sed() {
  printf '%s' "$1" | sed 's/[|&\\]/\\&/g'
}

generate_secret_value() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import secrets; print(secrets.token_hex(32))'
    return 0
  fi

  od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
}

render_template_file() {
  local src="$1"
  local dest="$2"

  sed \
    -e "s|__TENANT__|$(escape_sed "${TENANT:-}")|g" \
    -e "s|__TENANT_ROOT__|$(escape_sed "${TENANT_ROOT:-}")|g" \
    -e "s|__TENANT_HOME__|$(escape_sed "${TENANT_HOME:-}")|g" \
    -e "s|__OPENCLAW_PORT__|$(escape_sed "${OPENCLAW_PORT:-}")|g" \
    -e "s|__OPENCLAW_BRIDGE_PORT__|$(escape_sed "${OPENCLAW_BRIDGE_PORT:-}")|g" \
    -e "s|__BROWSER_PORT__|$(escape_sed "${BROWSER_PORT:-}")|g" \
    -e "s|__PARSER_PORT__|$(escape_sed "${PARSER_PORT:-}")|g" \
    -e "s|__CONTROL_PORT__|$(escape_sed "${CONTROL_PORT:-}")|g" \
    -e "s|__MODEL_ENDPOINT__|$(escape_sed "${MODEL_ENDPOINT:-}")|g" \
    -e "s|__PUBLIC_HOSTNAME__|$(escape_sed "${PUBLIC_HOSTNAME:-}")|g" \
    -e "s|__OPENCLAW_IMAGE__|$(escape_sed "${OPENCLAW_IMAGE:-}")|g" \
    -e "s|__BROWSER_IMAGE__|$(escape_sed "${BROWSER_IMAGE:-}")|g" \
    -e "s|__PARSER_IMAGE__|$(escape_sed "${PARSER_IMAGE:-}")|g" \
    -e "s|__AGENT_IMAGE__|$(escape_sed "${AGENT_IMAGE:-}")|g" \
    -e "s|__OPENCLAW_GATEWAY_TOKEN__|$(escape_sed "${OPENCLAW_GATEWAY_TOKEN:-}")|g" \
    "$src" > "$dest"
}

write_if_missing() {
  local mode="$1"
  local owner="$2"
  local group="$3"
  local src="$4"
  local dest="$5"

  if [ -e "$dest" ]; then
    return 0
  fi

  install -D -m "$mode" -o "$owner" -g "$group" "$src" "$dest"
}

restorecon_if_available() {
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -RF "$@" >/dev/null 2>&1 || true
  fi
}

try_user_systemctl() {
  local tenant="$1"
  shift

  runuser -u "$tenant" -- systemctl --user "$@" >/dev/null 2>&1
}
