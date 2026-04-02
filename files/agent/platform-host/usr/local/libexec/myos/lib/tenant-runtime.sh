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
      "myOS OpenClaw tenant ${tenant}"|myOS\ OpenClaw\ tenant*) ;;
      *) die "existing user ${tenant} does not look like a managed tenant account" ;;
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

tenant_service_name() { printf 'openclaw.service\n'; }

tenant_systemd_reachable() {
  try_user_systemctl "$1" show-environment
}

tenant_service_active() {
  try_user_systemctl "$1" is-active "$(tenant_service_name)"
}

tenant_service_active_state() {
  run_user_systemctl "$1" is-active "$(tenant_service_name)" 2>/dev/null || true
}

tenant_container_exists() {
  local tenant="$1"
  run_tenant_podman "$tenant" inspect "$(tenant_container_name "$tenant")" >/dev/null 2>&1
}

tenant_container_state() {
  local tenant="$1"
  run_tenant_podman "$tenant" inspect -f '{{.State.Status}}' "$(tenant_container_name "$tenant")" 2>/dev/null || true
}

tenant_container_running() {
  [ "$(run_tenant_podman "$1" inspect -f '{{.State.Running}}' "$(tenant_container_name "$1")" 2>/dev/null || true)" = true ]
}

tenant_container_health() {
  local tenant="$1"
  tenant_container_exists "$tenant" || return 1
  run_tenant_podman "$tenant" inspect -f '{{if .State.Healthcheck}}{{.State.Healthcheck.Status}}{{else}}unknown{{end}}' "$(tenant_container_name "$tenant")" 2>/dev/null || true
}

tenant_dashboard_responding() {
  local tenant="$1"
  local port

  port="$(tenant_gateway_port "$tenant" 2>/dev/null || true)"
  [ -n "$port" ] || return 1
  curl -fsS --max-time 3 "http://127.0.0.1:${port}/__openclaw/control-ui-config.json" >/dev/null 2>&1
}

tenant_openclaw_service_active() { tenant_service_active "$1"; }
tenant_openclaw_container_available() { tenant_container_exists "$1"; }

tenant_openclaw_runtime_available() {
  local tenant="$1"
  tenant_service_active "$tenant" || return 1
  tenant_container_exists "$tenant"
}

restart_tenant_openclaw_service() {
  local tenant="$1"
  local uid

  uid="$(id -u "$tenant" 2>/dev/null || true)"
  [ -n "$uid" ] || return 1

  systemctl start "user@${uid}.service"
  run_user_systemctl "$tenant" reset-failed "$(tenant_service_name)" || true
  run_user_systemctl "$tenant" restart "$(tenant_service_name)"
}

run_tenant_container_exec() {
  local tenant="$1"
  local container
  local -a args
  shift

  container="$(tenant_container_name "$tenant")"
  tenant_service_active "$tenant" || die "openclaw.service is not active for ${tenant}"
  tenant_container_exists "$tenant" || die "container ${container} is not running for ${tenant}"

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

tenant_models_status_plain() {
  run_tenant_openclaw_cli "$1" models status --plain 2>/dev/null || true
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
