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
    root)
      die "tenant name ${tenant} is reserved"
      ;;
  esac
}

ensure_dir() {
  local mode="$1"
  local owner="$2"
  local group="$3"
  local path="$4"

  install -d -m "$mode" -o "$owner" -g "$group" "$path"
}

restorecon_if_available() {
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -RF "$@" >/dev/null 2>&1 || true
  fi
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
