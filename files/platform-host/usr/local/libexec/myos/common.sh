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

  case "$tenant" in
    root|modelsvc)
      die "tenant name ${tenant} is reserved"
      ;;
  esac
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

tenant_rendered_dir() {
  printf '%s/rendered\n' "$(tenant_config_root "$1")"
}

tenant_secret_dir() {
  printf '%s/zone-c/secrets\n' "$(tenant_root "$1")"
}

tenant_secret_file() {
  printf '%s/openclaw.secrets.env\n' "$(tenant_secret_dir "$1")"
}

tenant_state_dir() {
  printf '%s/zone-c/state\n' "$(tenant_root "$1")"
}

tenant_config_file() {
  printf '%s/openclaw.json\n' "$(tenant_state_dir "$1")"
}

tenant_container_name() {
  printf 'openclaw-%s\n' "$1"
}

tenant_podman_root() {
  printf '/var/tmp/myos-podman/%s\n' "$1"
}

tenant_podman_graphroot() {
  printf '%s/storage\n' "$(tenant_podman_root "$1")"
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
  local home passwd_entry existing_gecos existing_home existing_shell

  install -d -m 0755 "$TENANT_BASE"
  home="$(tenant_home "$tenant")"
  passwd_entry="$(getent passwd "$tenant" 2>/dev/null || true)"

  if [ -z "$passwd_entry" ]; then
    useradd \
      --create-home \
      --home-dir "$home" \
      --shell /usr/sbin/nologin \
      --comment "myOS OpenClaw tenant ${tenant}" \
      "$tenant"
  else
    IFS=: read -r _ _ _ _ existing_gecos existing_home existing_shell <<< "$passwd_entry"
    [ "$existing_home" = "$home" ] || die "existing user ${tenant} is not managed under ${home}"
    [ "$existing_shell" = "/usr/sbin/nologin" ] || die "existing user ${tenant} is not a managed tenant account"
    case "$existing_gecos" in
      "myOS OpenClaw tenant ${tenant}"|myOS\ OpenClaw\ tenant*)
        ;;
      *)
        die "existing user ${tenant} does not look like a managed tenant account"
        ;;
    esac
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
    -e "s|__TENANT_UID__|$(escape_sed "${TENANT_UID:-}")|g" \
    -e "s|__TENANT_GID__|$(escape_sed "${TENANT_GID:-}")|g" \
    -e "s|__OPENCLAW_PORT__|$(escape_sed "${OPENCLAW_PORT:-}")|g" \
    -e "s|__OPENCLAW_BRIDGE_PORT__|$(escape_sed "${OPENCLAW_BRIDGE_PORT:-}")|g" \
    -e "s|__OPENCLAW_UI_PORT__|$(escape_sed "${OPENCLAW_UI_PORT:-}")|g" \
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
    -e "s|__OPENCLAW_MEMORY_MAX__|$(escape_sed "${OPENCLAW_MEMORY_MAX:-}")|g" \
    -e "s|__OPENCLAW_CPU_QUOTA__|$(escape_sed "${OPENCLAW_CPU_QUOTA:-}")|g" \
    -e "s|__OPENCLAW_TASKS_MAX__|$(escape_sed "${OPENCLAW_TASKS_MAX:-}")|g" \
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

tenant_runtime_dir() {
  printf '/run/user/%s\n' "$(id -u "$1")"
}

run_as_tenant_login() {
  local tenant="$1"
  local uid
  shift

  uid="$(id -u "$tenant" 2>/dev/null || true)"
  [ -n "$uid" ] || return 1

  runuser -u "$tenant" -- env \
    HOME="$(tenant_home "$tenant")" \
    XDG_RUNTIME_DIR="/run/user/${uid}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
    sh -lc 'cd "$HOME" && exec "$@"' sh "$@"
}

run_user_systemctl() {
  local tenant="$1"
  shift

  if systemctl --machine "${tenant}@" --user "$@"; then
    return 0
  fi

  run_as_tenant_login "$tenant" systemctl --user "$@"
}

try_user_systemctl() {
  local tenant="$1"
  shift

  run_user_systemctl "$tenant" "$@" >/dev/null 2>&1
}

run_tenant_podman() {
  local tenant="$1"
  shift

  run_as_tenant_login "$tenant" podman "$@"
}

env_value_from_file() {
  local file="$1"
  local key="$2"

  [ -f "$file" ] || return 1
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "", $0)
      print $0
      found = 1
      exit
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp found=0 line

  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"

  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" == "${key}="* ]]; then
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        found=1
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
  fi

  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi

  cat "$tmp" > "$file"
  rm -f "$tmp"
}

append_unique_csv_item() {
  local current="$1"
  local item="$2"
  local cleaned=""
  local part
  local -a parts=()

  IFS=',' read -r -a parts <<< "${current:-}"
  for part in "${parts[@]}"; do
    part="${part#"${part%%[![:space:]]*}"}"
    part="${part%"${part##*[![:space:]]}"}"
    [ -n "$part" ] || continue
    if [ "$part" = "$item" ]; then
      printf '%s\n' "$current"
      return 0
    fi
    cleaned="${cleaned:+${cleaned},}${part}"
  done

  printf '%s\n' "${cleaned:+${cleaned},}${item}"
}

normalize_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      printf 'true\n'
      ;;
    0|false|FALSE|no|NO|off|OFF|"")
      printf 'false\n'
      ;;
    *)
      die "expected a boolean value, got: ${1:-}"
      ;;
  esac
}

tenant_ui_url() {
  local tenant="$1"
  local port

  port="$(env_value_from_file "$(tenant_env_dir "$tenant")/ports.env" OPENCLAW_UI_PORT 2>/dev/null || true)"
  [ -n "$port" ] || return 1
  printf 'http://127.0.0.1:%s/\n' "$port"
}

tenant_gateway_ws_url() {
  local tenant="$1"
  local port

  port="$(env_value_from_file "$(tenant_env_dir "$tenant")/ports.env" OPENCLAW_PORT 2>/dev/null || true)"
  [ -n "$port" ] || return 1
  printf 'ws://127.0.0.1:%s\n' "$port"
}
