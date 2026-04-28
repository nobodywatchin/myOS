#!/usr/bin/env bash
set -Eeuo pipefail

MYOS_ETC="${MYOS_ETC:-/etc/myos}"
TENANT_BASE="${TENANT_BASE:-/srv/tenants}"
TEMPLATE_BASE="${TEMPLATE_BASE:-${MYOS_ETC}/templates/apps/openclaw}"
PERSISTENT_USER_TEMPLATE_BASE="${PERSISTENT_USER_TEMPLATE_BASE:-${MYOS_ETC}/templates/persistent-users}"
PERSISTENT_USER_STATE_BASE="${PERSISTENT_USER_STATE_BASE:-${MYOS_ETC}/persistent-users}"
PORT_STATE_FILE="${PORT_STATE_FILE:-${MYOS_ETC}/tenants/ports.state}"
PORT_LOCK_DIR="${PORT_LOCK_DIR:-/run/myos-port-allocate.lock}"
DEFAULT_OPENCLAW_IMAGE="${DEFAULT_OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}"
DEFAULT_OPENQUAD_IMAGE="${DEFAULT_OPENQUAD_IMAGE:-ghcr.io/myos-dev/openquad:latest}"
DEFAULT_TENANT_GATEWAY_MODE="${DEFAULT_TENANT_GATEWAY_MODE:-local}"
DEFAULT_TENANT_GATEWAY_RELOAD_MODE="${DEFAULT_TENANT_GATEWAY_RELOAD_MODE:-hybrid}"
DEFAULT_TENANT_PRIMARY_MODEL="${DEFAULT_TENANT_PRIMARY_MODEL:-openrouter/anthropic/claude-sonnet-4-5}"
DEFAULT_TENANT_ALLOW_INSECURE_AUTH="${DEFAULT_TENANT_ALLOW_INSECURE_AUTH:-false}"
OPENCLAW_OWNER_TENANT_NAME="${OPENCLAW_OWNER_TENANT_NAME:-owner-openclaw}"
OPENCLAW_USER_SERVICE_NAME="${OPENCLAW_USER_SERVICE_NAME:-openclaw.service}"
OPENCLAW_USER_CONTAINER_NAME="${OPENCLAW_USER_CONTAINER_NAME:-openclaw}"
OPENCLAW_USER_QUADLET_NAME="${OPENCLAW_USER_QUADLET_NAME:-openclaw.container}"
OPENQUAD_WRAPPER_VERSION="${OPENQUAD_WRAPPER_VERSION:-1.0.0}"

MYOS_LIBEXEC_DIR="${MYOS_LIBEXEC_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
MYOS_LIB_DIR="${MYOS_LIB_DIR:-${MYOS_LIBEXEC_DIR}/lib}"

for myos_lib in \
  core \
  paths \
  env \
  template \
  user-runtime
 do
  # shellcheck source=/dev/null
  . "${MYOS_LIB_DIR}/${myos_lib}.sh"
done

for myos_optional_lib in \
  tenant-runtime \
  tenant-config \
  tailscale \
  tenant-reconcile
 do
  [ -f "${MYOS_LIB_DIR}/${myos_optional_lib}.sh" ] || continue
  # shellcheck source=/dev/null
  . "${MYOS_LIB_DIR}/${myos_optional_lib}.sh"
done

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

openclaw_owner_tenant_name() {
  printf '%s\n' "$OPENCLAW_OWNER_TENANT_NAME"
}
