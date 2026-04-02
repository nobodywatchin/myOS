#!/usr/bin/env bash
set -Eeuo pipefail

MYOS_ETC="${MYOS_ETC:-/etc/myos}"
TENANT_BASE="${TENANT_BASE:-/srv/tenants}"
TEMPLATE_BASE="${TEMPLATE_BASE:-${MYOS_ETC}/templates/apps/openclaw}"
PERSISTENT_USER_TEMPLATE_BASE="${PERSISTENT_USER_TEMPLATE_BASE:-${MYOS_ETC}/templates/persistent-users}"
PERSISTENT_USER_STATE_BASE="${PERSISTENT_USER_STATE_BASE:-${MYOS_ETC}/persistent-users}"
PORT_STATE_FILE="${PORT_STATE_FILE:-${MYOS_ETC}/tenants/ports.state}"
PORT_LOCK_DIR="${PORT_LOCK_DIR:-/run/myos-port-allocate.lock}"
DEFAULT_OPENCLAW_IMAGE="${DEFAULT_OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:2026.3.13-1}"
OPENCLAW_USER_SERVICE_NAME="${OPENCLAW_USER_SERVICE_NAME:-openclaw.service}"
OPENCLAW_USER_CONTAINER_NAME="${OPENCLAW_USER_CONTAINER_NAME:-openclaw}"
OPENCLAW_USER_QUADLET_NAME="${OPENCLAW_USER_QUADLET_NAME:-openclaw.container}"
OPENQUAD_WRAPPER_VERSION="${OPENQUAD_WRAPPER_VERSION:-1.0.0}"

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

account_home() {
  getent passwd "$1" 2>/dev/null | awk -F: 'NR == 1 { print $6 }'
}

account_quadlet_dir() {
  printf '%s/.config/containers/systemd\n' "$(account_home "$1")"
}

account_systemd_user_dir() {
  printf '%s/.config/systemd/user\n' "$(account_home "$1")"
}

current_user_quadlet_dir() {
  printf '%s/containers/systemd\n' "${XDG_CONFIG_HOME:-${HOME}/.config}"
}

openclaw_user_quadlet_path() {
  printf '%s/%s\n' "$(current_user_quadlet_dir)" "$OPENCLAW_USER_QUADLET_NAME"
}

openclaw_user_quadlet_template_path() {
  printf '%s/%s\n' "$(persistent_user_template_dir baseline)" "$OPENCLAW_USER_QUADLET_NAME"
}

openclaw_user_quadlet_template_available() {
  [ -f "$(openclaw_user_quadlet_template_path)" ]
}

openclaw_user_service_name() {
  printf '%s\n' "$OPENCLAW_USER_SERVICE_NAME"
}

openclaw_user_container_name() {
  printf '%s\n' "$OPENCLAW_USER_CONTAINER_NAME"
}

openclaw_user_config_dir() {
  printf '%s/.config/myos\n' "$HOME"
}

openclaw_user_state_dir() {
  printf '%s/.local/share/openclaw\n' "$HOME"
}

openclaw_user_config_file() {
  printf '%s/openclaw.json\n' "$(openclaw_user_state_dir)"
}

openclaw_user_config_exists() {
  [ -f "$(openclaw_user_config_file)" ]
}

openclaw_user_workspace_dir() {
  printf '%s/workspace\n' "$(openclaw_user_state_dir)"
}

openclaw_user_logs_dir() {
  printf '%s/.local/state/openclaw/logs\n' "$HOME"
}

ensure_openclaw_user_runtime_dirs() {
  mkdir -p \
    "$(current_user_quadlet_dir)" \
    "$(openclaw_user_config_dir)" \
    "$(openclaw_user_state_dir)" \
    "$(openclaw_user_workspace_dir)" \
    "$(openclaw_user_logs_dir)"
}

current_user_systemctl() {
  systemctl --user "$@"
}

try_current_user_systemctl() {
  current_user_systemctl "$@" >/dev/null 2>&1
}

openclaw_user_service_installed() {
  [ -f "$(openclaw_user_quadlet_path)" ]
}

render_openclaw_user_quadlet() {
  local dest="$1"
  local template image

  template="$(openclaw_user_quadlet_template_path)"
  [ -f "$template" ] || return 1

  image="${OPENCLAW_IMAGE:-$DEFAULT_OPENCLAW_IMAGE}"
  ACCOUNT="$(id -un)" \
  ACCOUNT_HOME="$HOME" \
  ACCOUNT_UID="$(id -u)" \
  ACCOUNT_GID="$(id -g)" \
  OPENCLAW_IMAGE="$image" \
    render_template_file "$template" "$dest"
}

install_openclaw_user_quadlet_from_template() {
  local target tmp

  target="$(openclaw_user_quadlet_path)"
  [ -f "$target" ] && return 0
  openclaw_user_quadlet_template_available || return 1

  ensure_openclaw_user_runtime_dirs
  tmp="$(mktemp)"

  if ! render_openclaw_user_quadlet "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  install -m 0644 "$tmp" "$target"
  rm -f "$tmp"
  restorecon_if_available "$(current_user_quadlet_dir)" "$target"
}

openclaw_user_image_from_quadlet() {
  local quadlet

  quadlet="$(openclaw_user_quadlet_path)"
  [ -f "$quadlet" ] || return 1

  awk -F= '
    $1 == "Image" {
      sub(/^[^=]*=/, "", $0)
      print $0
      exit
    }
  ' "$quadlet"
}

persistent_user_template_dir() {
  printf '%s/%s/quadlets\n' "$PERSISTENT_USER_TEMPLATE_BASE" "$1"
}

persistent_user_state_dir() {
  printf '%s/users/%s\n' "$PERSISTENT_USER_STATE_BASE" "$1"
}

persistent_user_role_files_file() {
  printf '%s/%s.files\n' "$(persistent_user_state_dir "$1")" "$2"
}

persistent_user_role_units_file() {
  printf '%s/%s.units\n' "$(persistent_user_state_dir "$1")" "$2"
}

persistent_user_owner_file() {
  printf '%s/owner.conf\n' "$PERSISTENT_USER_STATE_BASE"
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

require_existing_account() {
  local account="${1:-}"
  local home

  [ -n "$account" ] || die "user name is required"
  getent passwd "$account" >/dev/null 2>&1 || die "user ${account} does not exist"

  home="$(account_home "$account")"
  [ -n "$home" ] || die "user ${account} does not have a home directory"
  [ -d "$home" ] || die "user ${account} home directory ${home} is missing"
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
    -e "s|__ACCOUNT__|$(escape_sed "${ACCOUNT:-${TENANT:-}}")|g" \
    -e "s|__ACCOUNT_HOME__|$(escape_sed "${ACCOUNT_HOME:-${TENANT_HOME:-}}")|g" \
    -e "s|__ACCOUNT_UID__|$(escape_sed "${ACCOUNT_UID:-${TENANT_UID:-}}")|g" \
    -e "s|__ACCOUNT_GID__|$(escape_sed "${ACCOUNT_GID:-${TENANT_GID:-}}")|g" \
    -e "s|__USER__|$(escape_sed "${ACCOUNT:-${TENANT:-}}")|g" \
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

list_managed_unit_templates() {
  local dir="$1"

  [ -d "$dir" ] || return 0

  find "$dir" -maxdepth 1 -type f \
    \( \
      -name '*.build' -o \
      -name '*.container' -o \
      -name '*.image' -o \
      -name '*.kube' -o \
      -name '*.network' -o \
      -name '*.pod' -o \
      -name '*.service' -o \
      -name '*.socket' -o \
      -name '*.target' -o \
      -name '*.timer' -o \
      -name '*.volume' \
    \) | sort
}

managed_service_unit_name_from_template() {
  local name

  name="$(basename "$1")"

  case "$name" in
    *.build|*.container|*.image|*.kube|*.pod)
      printf '%s.service\n' "${name%.*}"
      ;;
    *.service|*.socket|*.target|*.timer)
      printf '%s\n' "$name"
      ;;
    *)
      return 1
      ;;
  esac
}

managed_service_unit_requires_explicit_enable() {
  local name

  name="$(basename "$1")"

  case "$name" in
    *.service|*.socket|*.target|*.timer)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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
  local uid home
  shift

  uid="$(id -u "$tenant" 2>/dev/null || true)"
  [ -n "$uid" ] || return 1

  home="$(account_home "$tenant")"
  [ -n "$home" ] || return 1

  runuser -u "$tenant" -- env \
    HOME="$home" \
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

tenant_openclaw_service_active() {
  try_user_systemctl "$1" is-active openclaw.service
}

tenant_openclaw_container_available() {
  local tenant="$1"

  run_tenant_podman "$tenant" inspect "$(tenant_container_name "$tenant")" >/dev/null 2>&1
}

tenant_openclaw_runtime_available() {
  local tenant="$1"

  tenant_openclaw_service_active "$tenant" || return 1
  tenant_openclaw_container_available "$tenant"
}

restart_tenant_openclaw_service() {
  local tenant="$1"
  local uid

  uid="$(id -u "$tenant" 2>/dev/null || true)"
  [ -n "$uid" ] || return 1

  systemctl start "user@${uid}.service"
  run_user_systemctl "$tenant" reset-failed openclaw.service || true
  run_user_systemctl "$tenant" restart openclaw.service
}

run_tenant_container_exec() {
  local tenant="$1"
  local container
  local -a args
  shift

  container="$(tenant_container_name "$tenant")"
  tenant_openclaw_service_active "$tenant" || die "openclaw.service is not active for ${tenant}"
  tenant_openclaw_container_available "$tenant" || die "container ${container} is not running for ${tenant}"

  args=(exec)
  if [ -t 0 ] && [ -t 1 ]; then
    args+=(-it)
  else
    args+=(-i)
  fi

  args+=(
    --env HOME=/home/node
    --env OPENCLAW_STATE_DIR=/home/node/.openclaw
    --env OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json
    --workdir /home/node
    "$container"
  )

  run_tenant_podman "$tenant" "${args[@]}" "$@"
}

run_tenant_openclaw() {
  local tenant="$1"
  shift

  run_tenant_container_exec "$tenant" openclaw "$@"
}

tenant_openclaw_image() {
  env_value_from_file "$(tenant_env_dir "$1")/openclaw.env" OPENCLAW_IMAGE 2>/dev/null || printf '%s\n' "$DEFAULT_OPENCLAW_IMAGE"
}

run_tenant_openclaw_cli() {
  local tenant="$1"
  local image uid gid
  local -a args
  shift

  if tenant_openclaw_runtime_available "$tenant"; then
    run_tenant_openclaw "$tenant" "$@"
    return
  fi

  image="$(tenant_openclaw_image "$tenant")"
  uid="$(id -u "$tenant")"
  gid="$(id -g "$tenant")"

  args=(run --rm --security-opt label=disable --userns keep-id --user "${uid}:${gid}")
  if [ -t 0 ] && [ -t 1 ]; then
    args+=(-it)
  else
    args+=(-i)
  fi

  args+=(
    --env HOME=/home/node
    --env OPENCLAW_STATE_DIR=/home/node/.openclaw
    --env OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json
    --env OPENCLAW_GATEWAY_PORT=18789
    --env-file "$(tenant_env_dir "$tenant")/ports.env"
    --env-file "$(tenant_env_dir "$tenant")/common.env"
    --env-file "$(tenant_env_dir "$tenant")/openclaw.env"
    --env-file "$(tenant_secret_file "$tenant")"
    --workdir /home/node
    -v "$(tenant_root "$tenant")/zone-c/state:/home/node/.openclaw:Z"
    -v "$(tenant_root "$tenant")/zone-c/storage:/home/node/.openclaw/workspace:Z"
    -v "$(tenant_root "$tenant")/logs:/tmp/openclaw:Z"
    "$image"
    openclaw
  )

  run_tenant_podman "$tenant" "${args[@]}" "$@"
}

persistent_user_owner() {
  env_value_from_file "$(persistent_user_owner_file)" OWNER_USER 2>/dev/null || true
}

persistent_user_is_owner() {
  local account="$1"

  [ "$(persistent_user_owner 2>/dev/null || true)" = "$account" ]
}

set_persistent_user_owner() {
  local account="${1:-}"
  local owner_file

  owner_file="$(persistent_user_owner_file)"
  ensure_dir 0755 root root "$PERSISTENT_USER_STATE_BASE"

  if [ -n "$account" ]; then
    require_existing_account "$account"
    set_env_value "$owner_file" OWNER_USER "$account"
    chown root:root "$owner_file"
    chmod 0644 "$owner_file"
    restorecon_if_available "$owner_file"
  else
    rm -f "$owner_file"
  fi
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

tenant_gateway_port() {
  env_value_from_file "$(tenant_env_dir "$1")/ports.env" OPENCLAW_PORT 2>/dev/null
}

tenant_ui_url() {
  local tenant="$1"
  local port

  port="$(tenant_gateway_port "$tenant" || true)"
  [ -n "$port" ] || return 1
  printf 'http://127.0.0.1:%s/\n' "$port"
}

tenant_gateway_ws_url() {
  local tenant="$1"
  local port

  port="$(tenant_gateway_port "$tenant" || true)"
  [ -n "$port" ] || return 1
  printf 'ws://127.0.0.1:%s\n' "$port"
}

tenant_primary_model_from_config() {
  local config_file

  config_file="$(tenant_config_file "$1")"
  [ -f "$config_file" ] || return 1
  python3 - "$config_file" <<'PYTHON'
import json
import sys

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit(1)

model = (
    data.get('agents', {})
        .get('defaults', {})
        .get('model', {})
        .get('primary', '')
)
if isinstance(model, str) and model.strip():
    print(model.strip())
PYTHON
}



tenant_common_env_file() {
  printf '%s/common.env
' "$(tenant_env_dir "$1")"
}

tenant_tailscale_exposure() {
  local value

  value="$(env_value_from_file "$(tenant_common_env_file "$1")" TAILSCALE_EXPOSURE 2>/dev/null || true)"
  printf '%s
' "${value:-off}"
}

tenant_tailscale_last_origin() {
  env_value_from_file "$(tenant_common_env_file "$1")" TAILSCALE_LAST_ORIGIN 2>/dev/null || true
}

tailscale_installed() {
  command -v tailscale >/dev/null 2>&1
}

tailscale_service_active() {
  systemctl is-active --quiet tailscaled.service
}

tailscale_status_json() {
  tailscale status --json
}

tailscale_self_dns_name() {
  local status

  status="$(tailscale_status_json 2>/dev/null)" || return 1
  STATUS_JSON="$status" python3 - <<'PYTHON'
import json
import os

raw = os.environ.get('STATUS_JSON', '').strip()
if not raw:
    raise SystemExit(1)

try:
    data = json.loads(raw)
except Exception:
    raise SystemExit(1)

self_info = data.get('Self') if isinstance(data, dict) else None
if not isinstance(self_info, dict):
    raise SystemExit(1)

dns_name = self_info.get('DNSName')
if not isinstance(dns_name, str) or not dns_name.strip():
    raise SystemExit(1)

print(dns_name.rstrip('.'))
PYTHON
}

tailscale_require_ready() {
  local dns

  tailscale_installed || die "tailscale CLI is not installed on the host"
  tailscale_service_active || die "tailscaled.service is not active on the host"
  dns="$(tailscale_self_dns_name 2>/dev/null || true)"
  [ -n "$dns" ] || die "tailscale is not logged in or does not have a MagicDNS name yet"
  printf '%s
' "$dns"
}

tenant_tailscale_origin() {
  local tenant="$1"
  local dns port

  dns="$(tailscale_self_dns_name 2>/dev/null)" || return 1
  port="$(tenant_gateway_port "$tenant" || true)"
  [ -n "$port" ] || return 1
  printf 'https://%s:%s
' "$dns" "$port"
}

tenant_tailscale_http_url() {
  local origin

  origin="$(tenant_tailscale_origin "$1" 2>/dev/null)" || return 1
  printf '%s/
' "$origin"
}

tenant_tailscale_ws_url() {
  local tenant="$1"
  local dns port

  dns="$(tailscale_self_dns_name 2>/dev/null)" || return 1
  port="$(tenant_gateway_port "$tenant" || true)"
  [ -n "$port" ] || return 1
  printf 'wss://%s:%s/
' "$dns" "$port"
}

tenant_tailscale_target() {
  local port

  port="$(tenant_gateway_port "$1" || true)"
  [ -n "$port" ] || return 1
  printf 'http://127.0.0.1:%s
' "$port"
}

tailscale_serve_status_json() {
  tailscale serve status --json
}

tailscale_serve_has_mapping() {
  local port="$1"
  local target="$2"
  local status

  status="$(tailscale_serve_status_json 2>/dev/null)" || return 1
  STATUS_JSON="$status" python3 - "$port" "$target" <<'PYTHON'
import json
import os
import sys

port = str(sys.argv[1])
target = sys.argv[2]
raw = os.environ.get('STATUS_JSON', '').strip()
if not raw:
    raise SystemExit(1)

try:
    data = json.loads(raw)
except Exception:
    raise SystemExit(1)

def has_target(node):
    if isinstance(node, str):
        return target in node
    if isinstance(node, dict):
        return any(has_target(k) or has_target(v) for k, v in node.items())
    if isinstance(node, list):
        return any(has_target(item) for item in node)
    return False

def matches_port(value):
    text = str(value)
    return text == port or text.endswith(f":{port}") or text.endswith(f"]:{port}")

def contains_port(node):
    if isinstance(node, dict):
        if any(matches_port(k) or matches_port(v) for k, v in node.items()) and has_target(node):
            return True
        return any(contains_port(k) or contains_port(v) for k, v in node.items())
    if isinstance(node, list):
        return any(contains_port(item) for item in node)
    return False

raise SystemExit(0 if contains_port(data) else 1)
PYTHON
}

tenant_control_ui_allowed_origins_json() {
  local tenant="$1"
  local config_file

  config_file="$(tenant_config_file "$tenant")"
  if [ ! -f "$config_file" ]; then
    printf '[]
'
    return 0
  fi

  python3 - "$config_file" <<'PYTHON'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])

try:
    data = json.loads(config_path.read_text(encoding='utf-8'))
except Exception:
    print('[]')
    raise SystemExit(0)

origins = (
    data.get('gateway', {})
        .get('controlUi', {})
        .get('allowedOrigins', [])
)
if isinstance(origins, list):
    cleaned = [item for item in origins if isinstance(item, str)]
    print(json.dumps(cleaned, separators=(',', ':')))
else:
    print('[]')
PYTHON
}

tenant_control_ui_has_origin() {
  local tenant="$1"
  local origin="$2"
  local origins

  origins="$(tenant_control_ui_allowed_origins_json "$tenant")"
  ALLOWED_ORIGINS_JSON="$origins" python3 - "$origin" <<'PYTHON'
import json
import os
import sys

origin = sys.argv[1]
raw = os.environ.get('ALLOWED_ORIGINS_JSON', '').strip()
if not raw:
    raise SystemExit(1)

try:
    data = json.loads(raw)
except Exception:
    raise SystemExit(1)

raise SystemExit(0 if isinstance(data, list) and origin in data else 1)
PYTHON
}

tenant_device_pair_public_url() {
  local tenant="$1"
  local config_file

  config_file="$(tenant_config_file "$tenant")"
  [ -f "$config_file" ] || return 1

  python3 - "$config_file" <<'PYTHON'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])

try:
    data = json.loads(config_path.read_text(encoding='utf-8'))
except Exception:
    raise SystemExit(1)

value = (
    data.get('plugins', {})
        .get('entries', {})
        .get('device-pair', {})
        .get('config', {})
        .get('publicUrl', '')
)

if isinstance(value, str) and value.strip():
    print(value.strip())
    raise SystemExit(0)

raise SystemExit(1)
PYTHON
}

tenant_sync_control_ui_origins() {
  local tenant="$1"
  local add_origin="${2:-}"
  local remove_csv="${3:-}"
  local set_public_url="${4:-}"
  local clear_public_url_csv="${5:-}"
  local config_file
  local changed

  config_file="$(tenant_config_file "$tenant")"
  [ -f "$config_file" ] || return 1

  changed="$(python3 - "$config_file" "$add_origin" "$remove_csv" "$set_public_url" "$clear_public_url_csv" <<'PYTHON'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
add_origin = sys.argv[2].strip()
remove_csv = sys.argv[3]
set_public_url = sys.argv[4].strip()
clear_public_url_csv = sys.argv[5]
remove = {item.strip() for item in remove_csv.split(',') if item.strip()}
clear_public_urls = {item.strip() for item in clear_public_url_csv.split(',') if item.strip()}

try:
    data = json.loads(config_path.read_text(encoding='utf-8'))
except Exception:
    raise SystemExit(1)

if not isinstance(data, dict):
    data = {}

gateway = data.get('gateway')
if not isinstance(gateway, dict):
    gateway = {}
    data['gateway'] = gateway

control_ui = gateway.get('controlUi')
if not isinstance(control_ui, dict):
    control_ui = {}
    gateway['controlUi'] = control_ui

origins = control_ui.get('allowedOrigins')
source_origins = origins if isinstance(origins, list) else []
if not isinstance(origins, list):
    origins = []

out = []
seen = set()
for item in source_origins:
    if not isinstance(item, str):
        continue
    if item in remove:
        continue
    if item in seen:
        continue
    seen.add(item)
    out.append(item)

if add_origin and add_origin not in seen:
    out.append(add_origin)

changed = out != source_origins
control_ui['allowedOrigins'] = out

plugins = data.get('plugins')
if not isinstance(plugins, dict):
    plugins = {}
    data['plugins'] = plugins

entries = plugins.get('entries')
if not isinstance(entries, dict):
    entries = {}
    plugins['entries'] = entries

device_pair = entries.get('device-pair')
if not isinstance(device_pair, dict):
    device_pair = {}
    entries['device-pair'] = device_pair

plugin_config = device_pair.get('config')
if not isinstance(plugin_config, dict):
    plugin_config = {}
    device_pair['config'] = plugin_config

current_public_url = plugin_config.get('publicUrl')
if not isinstance(current_public_url, str):
    current_public_url = ''

if set_public_url:
    if current_public_url != set_public_url:
        plugin_config['publicUrl'] = set_public_url
        changed = True
else:
    should_remove_public_url = False
    if current_public_url:
        if clear_public_urls:
            should_remove_public_url = current_public_url in clear_public_urls
        else:
            should_remove_public_url = True
    if should_remove_public_url:
        plugin_config.pop('publicUrl', None)
        changed = True

    if not plugin_config:
        device_pair.pop('config', None)
    if not device_pair:
        entries.pop('device-pair', None)
    if not entries:
        plugins.pop('entries', None)
    if not plugins:
        data.pop('plugins', None)

if not changed:
    print('unchanged')
    raise SystemExit(0)

config_path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
print('changed')
PYTHON
)" || return 1

  if [ "$changed" = "unchanged" ]; then
    return 0
  fi

  chown "$tenant:$tenant" "$config_file"
  chmod 0640 "$config_file"
  restorecon_if_available "$config_file"
}
