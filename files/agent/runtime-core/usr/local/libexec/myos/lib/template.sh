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
