rebase:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$(
      printf '%s\n' \
        gnome-alma10:latest \
        gnome-alma10-nvidia-open:latest \
        gnome-alma9:latest \
        gnome-alma9-nvidia-open:latest \
        gnome-alma9-nvidia-legacy:latest \
      | fzf --prompt='Select image: '
    )"

    test -n "$sel" || { echo "No image selected"; exit 1; }

    ref="ghcr.io/myos-dev/${sel}"
    echo "Selected: $ref"
    echo "Executing: sudo bootc switch $ref"
    sudo bootc switch "$ref"
    echo "bootc auto-apply is disabled in myOS; reboot when you are ready to activate the new image."
