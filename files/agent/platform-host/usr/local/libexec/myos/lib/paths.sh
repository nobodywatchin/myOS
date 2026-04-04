tenant_root() { printf '%s/%s\n' "$TENANT_BASE" "$1"; }
tenant_home() { printf '%s/home\n' "$(tenant_root "$1")"; }
tenant_config_root() { printf '%s/config\n' "$(tenant_root "$1")"; }
tenant_env_dir() { printf '%s/env\n' "$(tenant_config_root "$1")"; }
tenant_rendered_dir() { printf '%s/rendered\n' "$(tenant_config_root "$1")"; }
tenant_secret_dir() { printf '%s/zone-c/secrets\n' "$(tenant_root "$1")"; }
tenant_secret_file() { printf '%s/openclaw.secrets.env\n' "$(tenant_secret_dir "$1")"; }
tenant_state_dir() { printf '%s/zone-c/state\n' "$(tenant_root "$1")"; }
tenant_config_file() { printf '%s/openclaw.json\n' "$(tenant_state_dir "$1")"; }
tenant_container_name() { printf 'openclaw-%s\n' "$1"; }
tenant_podman_root() { printf '/var/tmp/myos-podman/%s\n' "$1"; }
tenant_podman_graphroot() { printf '%s/storage\n' "$(tenant_podman_root "$1")"; }

tenant_common_env_file() { printf '%s/common.env\n' "$(tenant_env_dir "$1")"; }

tenant_runtime_dir() { printf '/run/user/%s\n' "$(id -u "$1")"; }

account_home() { getent passwd "$1" 2>/dev/null | awk -F: 'NR == 1 { print $6 }'; }
account_quadlet_dir() { printf '%s/.config/containers/systemd\n' "$(account_home "$1")"; }
account_systemd_user_dir() { printf '%s/.config/systemd/user\n' "$(account_home "$1")"; }

current_user_quadlet_dir() { printf '%s/containers/systemd\n' "${XDG_CONFIG_HOME:-${HOME}/.config}"; }
openclaw_user_quadlet_path() { printf '%s/%s\n' "$(current_user_quadlet_dir)" "$OPENCLAW_USER_QUADLET_NAME"; }
persistent_user_template_dir() { printf '%s/%s/quadlets\n' "$PERSISTENT_USER_TEMPLATE_BASE" "$1"; }
openclaw_user_quadlet_template_path() { printf '%s/user/%s\n' "$TEMPLATE_BASE" "$OPENCLAW_USER_QUADLET_NAME"; }
openclaw_user_config_dir() { printf '%s/.config/myos\n' "$HOME"; }
openclaw_user_state_dir() { printf '%s/.local/share/openclaw\n' "$HOME"; }
openclaw_user_config_file() { printf '%s/openclaw.json\n' "$(openclaw_user_state_dir)"; }
openclaw_user_workspace_dir() { printf '%s/workspace\n' "$(openclaw_user_state_dir)"; }
openclaw_user_logs_dir() { printf '%s/.local/state/openclaw/logs\n' "$HOME"; }

persistent_user_state_dir() { printf '%s/users/%s\n' "$PERSISTENT_USER_STATE_BASE" "$1"; }
persistent_user_role_files_file() { printf '%s/%s.files\n' "$(persistent_user_state_dir "$1")" "$2"; }
persistent_user_role_units_file() { printf '%s/%s.units\n' "$(persistent_user_state_dir "$1")" "$2"; }
persistent_user_owner_file() { printf '%s/owner.conf\n' "$PERSISTENT_USER_STATE_BASE"; }
