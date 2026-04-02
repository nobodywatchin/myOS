tenant_tailscale_exposure() {
  local value

  value="$(env_value_from_file "$(tenant_common_env_file "$1")" TAILSCALE_EXPOSURE 2>/dev/null || true)"
  printf '%s\n' "${value:-off}"
}

tenant_tailscale_last_origin() {
  env_value_from_file "$(tenant_common_env_file "$1")" TAILSCALE_LAST_ORIGIN 2>/dev/null || true
}

tailscale_installed() { command -v tailscale >/dev/null 2>&1; }
tailscale_service_active() { systemctl is-active --quiet tailscaled.service; }
tailscale_status_json() { tailscale status --json; }

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
  printf '%s\n' "$dns"
}

tenant_tailscale_origin() {
  local tenant="$1"
  local dns port

  dns="$(tailscale_self_dns_name 2>/dev/null)" || return 1
  port="$(tenant_gateway_port "$tenant" || true)"
  [ -n "$port" ] || return 1
  printf 'https://%s:%s\n' "$dns" "$port"
}

tenant_tailscale_http_url() {
  local origin

  origin="$(tenant_tailscale_origin "$1" 2>/dev/null)" || return 1
  printf '%s/\n' "$origin"
}

tenant_tailscale_ws_url() {
  local tenant="$1"
  local dns port

  dns="$(tailscale_self_dns_name 2>/dev/null)" || return 1
  port="$(tenant_gateway_port "$tenant" || true)"
  [ -n "$port" ] || return 1
  printf 'wss://%s:%s/\n' "$dns" "$port"
}

tenant_tailscale_target() {
  local port

  port="$(tenant_gateway_port "$1" || true)"
  [ -n "$port" ] || return 1
  printf 'http://127.0.0.1:%s\n' "$port"
}

tailscale_serve_status_json() { tailscale serve status --json; }

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
    printf '[]\n'
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
