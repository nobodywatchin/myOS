tenant_reconcile_quadlet() {
  local tenant="$1"
  local restart_mode="${2:-no}"
  local validate_mode="${3:-no}"
  local -a args

  args=(--tenant "$tenant" --force)
  [ "$restart_mode" = yes ] && args+=(--restart)
  [ "$validate_mode" = yes ] && args+=(--validate)

  /usr/local/libexec/myos/tenant-quadlet-install "${args[@]}"
}

tenant_reconcile_tailscale_if_enabled() {
  local tenant="$1"

  if [ "$(tenant_tailscale_exposure "$tenant")" = serve ]; then
    /usr/local/libexec/myos/tenant-tailscale reconcile --tenant "$tenant"
  fi
}

tenant_validate_runtime() {
  local tenant="$1"
  local require_running="${2:-no}"
  local -a args

  args=(--tenant "$tenant")
  [ "$require_running" = yes ] && args+=(--require-running)

  /usr/local/libexec/myos/tenant-validate "${args[@]}"
}

tenant_reconcile_and_restart_openclaw() {
  local tenant="$1"

  validate_tenant "$tenant"
  tenant_validate_runtime "$tenant"
  tenant_reconcile_quadlet "$tenant" yes yes
  tenant_reconcile_tailscale_if_enabled "$tenant"
}

tenant_apply_config_runtime_changes() {
  local tenant="$1"
  local needs_quadlet="${2:-no}"
  local restart_mode="${3:-no}"

  if [ "$needs_quadlet" = yes ]; then
    tenant_reconcile_quadlet "$tenant" "$restart_mode" "$([ "$restart_mode" = yes ] && printf yes || printf no)"
  elif [ "$restart_mode" = yes ]; then
    restart_tenant_openclaw_service "$tenant"
    tenant_validate_runtime "$tenant" yes
  fi

  if [ "$restart_mode" = yes ]; then
    tenant_reconcile_tailscale_if_enabled "$tenant"
  fi
}
