# Resolve the best hardened_malloc path on the host (with glibc-hwcaps if available)
hmalloc-path:
    #!/usr/bin/bash
    set -euo pipefail
    best_uarch="$(/usr/lib64/ld-linux-x86-64.so.2 --help | grep -F '(supported, searched)' \
        | grep -o 'x86-64-v[[:digit:]]*' | sort -nr | head -n1 || true)"
    if [[ -n "${best_uarch:-}" ]] && [[ -f "/var/run/host/usr/lib64/glibc-hwcaps/${best_uarch}/libhardened_malloc.so" ]]; then
        echo "/var/run/host/usr/lib64/glibc-hwcaps/${best_uarch}/libhardened_malloc.so"
    elif [[ -f "/var/run/host/usr/lib64/libhardened_malloc.so" ]]; then
        echo "/var/run/host/usr/lib64/libhardened_malloc.so"
    else
        echo "ERROR: libhardened_malloc.so not found on host. Layer or install it first." >&2
        exit 1
    fi

# Enable hardened_malloc for a specific Flatpak application ID (per-user)
enable-hmalloc FLATPAK_APPID:
    #!/usr/bin/bash
    set -euo pipefail
    appid="{{FLATPAK_APPID}}"
    if [[ -z "$appid" ]]; then
        echo "Usage: just enable-hmalloc FLATPAK_APPID" >&2
        exit 2
    fi

    # Verify app exists
    if ! flatpak list --app --columns=application | grep -Fxq "$appid"; then
        echo "Flatpak '$appid' not installed." >&2
        echo "Installed app IDs:" >&2
        flatpak list --app --columns=application | sort >&2
        exit 3
    fi

    # Resolve path on host (as seen from sandbox via /var/run/host)
    hmalloc_path="$(just --justfile "$JUSTFILE" hmalloc-path)"
    # Allow app to access host OS (read-only) so LD_PRELOAD path resolves
    flatpak override --user --filesystem=host-os:ro "$appid"

    # Remove any existing LD_PRELOAD override to avoid duplicates/conflicts
    # (flatpak override writes to ~/.local/share/flatpak/overrides/<appid>)
    overrides_file="$HOME/.local/share/flatpak/overrides/$appid"
    if [[ -f "$overrides_file" ]]; then
        sed -i '/^LD_PRELOAD=/d' "$overrides_file"
    fi

    # Apply LD_PRELOAD for this app only
    flatpak override --user --env=LD_PRELOAD="$hmalloc_path" "$appid"

    echo "Enabled hardened_malloc for $appid"
    echo "  LD_PRELOAD=$hmalloc_path"
    echo "  + filesystem=host-os:ro"

# Disable hardened_malloc for a specific Flatpak application ID (per-user)
disable-hmalloc FLATPAK_APPID:
    #!/usr/bin/bash
    set -euo pipefail
    appid="{{FLATPAK_APPID}}"
    if [[ -z "$appid" ]]; then
        echo "Usage: just disable-hmalloc FLATPAK_APPID" >&2
        exit 2
    fi

    overrides_file="$HOME/.local/share/flatpak/overrides/$appid"
    if [[ -f "$overrides_file" ]]; then
        # Drop LD_PRELOAD line
        sed -i '/^LD_PRELOAD=/d' "$overrides_file"
        # Optionally drop host-os grant if you only used it for hmalloc
        # Comment the next line if the app needs host-os for other reasons
        sed -Ei '/^filesystems=/s/(^|;)host-os(:ro)?($|;)/\1\3/; s/;;/;/' "$overrides_file"
        # Clean up empty 'filesystems=' assignments (optional)
        sed -i '/^filesystems=$/d' "$overrides_file"
    fi

    echo "Disabled hardened_malloc for $appid"

# Show effective env/filesystem overrides for an app
show-flatpak-overrides FLATPAK_APPID:
    #!/usr/bin/bash
    set -euo pipefail
    appid="{{FLATPAK_APPID}}"
    if [[ -z "$appid" ]]; then
        echo "Usage: just show-flatpak-overrides FLATPAK_APPID" >&2
        exit 2
    fi
    echo "Flatpak override (user) for: $appid"
    flatpak info --show-permissions "$appid" || true
    echo
    overrides_file="$HOME/.local/share/flatpak/overrides/$appid"
    if [[ -f "$overrides_file" ]]; then
        echo "Raw overrides file:"
        echo "  $overrides_file"
        sed 's/^/    /' "$overrides_file"
    else
        echo "No per-app overrides file found."
    fi

# List all apps currently hardened via LD_PRELOAD
list-hmalloc-enabled:
    #!/usr/bin/bash
    set -euo pipefail
    dir="$HOME/.local/share/flatpak/overrides"
    shopt -s nullglob
    found=0
    for f in "$dir"/*; do
        [[ -f "$f" ]] || continue
        if grep -Fqx 'LD_PRELOAD=/var/run/host/usr/lib64/libhardened_malloc.so' "$f" \
           || grep -Fq  '/var/run/host/usr/lib64/glibc-hwcaps/' "$f"; then
            echo "$(basename "$f")"
            found=1
        fi
    done
    if [[ $found -eq 0 ]]; then
        echo "No apps currently LD_PRELOADing hardened_malloc."
    fi

# Prune system Flatpaks not in BlueBuild defaults
prune-system-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail

    config="/usr/share/bluebuild/default-flatpaks/configuration.yaml"

    if ! command -v yq >/dev/null 2>&1; then
      echo "Error: yq is required. Install yq first." >&2
      exit 1
    fi

    # Collect desired system app IDs from the config
    mapfile -t desired < <(yq -r '.[] | select(.scope=="system") | .install[]?' "$config" | sed '/^\s*$/d')

    if [[ ${#desired[@]} -eq 0 ]]; then
      echo "No desired system Flatpaks found in config; aborting to avoid removing everything." >&2
      exit 2
    fi

    # Build a set for fast membership checks
    declare -A desired_set=()
    for app in "${desired[@]}"; do
      desired_set["$app"]=1
    done

    # Get current system-wide apps (apps only; no runtimes)
    mapfile -t installed < <(flatpak list --system --app --columns=application)

    echo "Pruning system Flatpaks not in the default list..."
    removed_any=0
    for app in "${installed[@]}"; do
      if [[ -z "${desired_set[$app]:-}" ]]; then
        echo "Removing extra: $app"
        sudo flatpak --system -y uninstall "$app"
        removed_any=1
      fi
    done

    if [[ "$removed_any" -eq 0 ]]; then
      echo "Nothing to prune. System Flatpaks already match your defaults."
    fi
