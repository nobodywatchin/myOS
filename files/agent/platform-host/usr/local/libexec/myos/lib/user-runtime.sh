openclaw_user_quadlet_template_available() {
  [ -f "$(openclaw_user_quadlet_template_path)" ]
}

openclaw_user_service_name() { printf '%s\n' "$OPENCLAW_USER_SERVICE_NAME"; }
openclaw_user_container_name() { printf '%s\n' "$OPENCLAW_USER_CONTAINER_NAME"; }
openclaw_user_config_exists() { [ -f "$(openclaw_user_config_file)" ]; }

ensure_openclaw_user_runtime_dirs() {
  mkdir -p \
    "$(current_user_quadlet_dir)" \
    "$(openclaw_user_config_dir)" \
    "$(openclaw_user_state_dir)" \
    "$(openclaw_user_workspace_dir)" \
    "$(openclaw_user_logs_dir)"
}

current_user_systemctl() { systemctl --user "$@"; }
try_current_user_systemctl() { current_user_systemctl "$@" >/dev/null 2>&1; }

user_runtime_prereqs_available() {
  command -v podman >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1
}

user_runtime_manager_available() {
  try_current_user_systemctl show-environment
}

openclaw_user_service_installed() {
  [ -f "$(openclaw_user_quadlet_path)" ]
}

user_runtime_service_enabled_state() {
  current_user_systemctl is-enabled "$(openclaw_user_service_name)" 2>/dev/null || true
}

user_runtime_service_active_state() {
  current_user_systemctl is-active "$(openclaw_user_service_name)" 2>/dev/null || true
}

user_runtime_service_active() {
  try_current_user_systemctl is-active "$(openclaw_user_service_name)"
}

user_runtime_container_state() {
  podman inspect -f '{{.State.Status}}' "$(openclaw_user_container_name)" 2>/dev/null || true
}

user_runtime_container_exists() {
  podman inspect "$(openclaw_user_container_name)" >/dev/null 2>&1
}

user_runtime_container_running() {
  [ "$(podman inspect -f '{{.State.Running}}' "$(openclaw_user_container_name)" 2>/dev/null || true)" = true ]
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

reinstall_openclaw_user_quadlet_from_template() {
  local target tmp changed=0

  target="$(openclaw_user_quadlet_path)"
  openclaw_user_quadlet_template_available || return 1

  ensure_openclaw_user_runtime_dirs
  tmp="$(mktemp)"

  if ! render_openclaw_user_quadlet "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if [ ! -f "$target" ] || ! cmp -s "$tmp" "$target"; then
    install -m 0644 "$tmp" "$target"
    changed=1
  fi

  rm -f "$tmp"
  restorecon_if_available "$(current_user_quadlet_dir)" "$target"
  return "$changed"
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

user_runtime_container_image() {
  podman inspect -f '{{.ImageName}}' "$(openclaw_user_container_name)" 2>/dev/null || openclaw_user_image_from_quadlet 2>/dev/null || true
}

user_runtime_inner_openclaw_version() {
  user_runtime_container_exists || return 1
  podman exec "$(openclaw_user_container_name)" openclaw --version 2>/dev/null | head -n 1
}

user_runtime_exec_args() {
  local -a args

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
    "$(openclaw_user_container_name)"
    openclaw
  )

  printf '%s\0' "${args[@]}"
}
