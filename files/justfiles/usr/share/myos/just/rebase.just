rebase:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$(
      printf '%s\n' \
        workstation-alma10:latest \
        workstation-alma10-nvidia:latest \
        workstation-alma9:latest \
        workstation-alma9-nvidia:latest \
      | fzf --prompt='Select image: '
    )"

    test -n "$sel" || { echo "No image selected"; exit 1; }

    ref="ghcr.io/myos-dev/${sel}"
    echo "Selected: $ref"
    echo "Executing: sudo bootc switch $ref"
    sudo bootc switch "$ref"
    echo "bootc auto-apply is disabled in myOS; reboot when you are ready to activate the new image."
