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
