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
