rebase:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$({
      printf '%s\n' \
        'Workstation | full | GNOME | alma10 | default | gnome-alma10:latest' \
        'Workstation | full | GNOME | alma10 | nvidia-open | gnome-alma10-nvidia-open:latest' \
        'Workstation | full | GNOME | alma9 | default | gnome-alma9:latest' \
        'Workstation | full | GNOME | alma9 | nvidia-open | gnome-alma9-nvidia-open:latest' \
        'Workstation | full | GNOME | alma9 | nvidia-legacy | gnome-alma9-nvidia-legacy:latest' \
        'Workstation | full | COSMIC | alma10 | default | cosmic-alma10:latest' \
        'Workstation | full | COSMIC | alma10 | nvidia-open | cosmic-alma10-nvidia-open:latest' \
        'Workstation | full | COSMIC | alma9 | default | cosmic-alma9:latest' \
        'Workstation | full | COSMIC | alma9 | nvidia-open | cosmic-alma9-nvidia-open:latest' \
        'Workstation | full | COSMIC | alma9 | nvidia-legacy | cosmic-alma9-nvidia-legacy:latest' \
        'Workstation | core | GNOME | alma10 | default | workstation-core-gnome-alma10:latest' \
        'Workstation | core | GNOME | alma10 | nvidia-open | workstation-core-gnome-alma10-nvidia-open:latest' \
        'Workstation | core | GNOME | alma9 | default | workstation-core-gnome-alma9:latest' \
        'Workstation | core | GNOME | alma9 | nvidia-open | workstation-core-gnome-alma9-nvidia-open:latest' \
        'Workstation | core | GNOME | alma9 | nvidia-legacy | workstation-core-gnome-alma9-nvidia-legacy:latest' \
        'Workstation | core | COSMIC | alma10 | default | workstation-core-cosmic-alma10:latest' \
        'Workstation | core | COSMIC | alma10 | nvidia-open | workstation-core-cosmic-alma10-nvidia-open:latest' \
        'Workstation | core | COSMIC | alma9 | default | workstation-core-cosmic-alma9:latest' \
        'Workstation | core | COSMIC | alma9 | nvidia-open | workstation-core-cosmic-alma9-nvidia-open:latest' \
        'Workstation | core | COSMIC | alma9 | nvidia-legacy | workstation-core-cosmic-alma9-nvidia-legacy:latest' \
        'Server | full | - | alma10 | default | core-full-alma10:latest' \
        'Server | full | - | alma10 | nvidia-open | core-full-alma10-nvidia-open:latest' \
        'Server | full | - | alma9 | default | core-full-alma9:latest' \
        'Server | full | - | alma9 | nvidia-open | core-full-alma9-nvidia-open:latest' \
        'Server | full | - | alma9 | nvidia-legacy | core-full-alma9-nvidia-legacy:latest' \
        'Console | core | preview | alma10 | default | console-core-alma10:latest' \
        'Console | core | preview | alma10 | nvidia-open | console-core-alma10-nvidia-open:latest'
    } | fzf \
      --delimiter='\|' \
      --with-nth=1,2,3,4,5 \
      --header='Role | Tier | Family | Distro | Hardware' \
      --prompt='Select image: ')"

    test -n "$sel" || { echo "No image selected"; exit 1; }

    tag="$(printf '%s\n' "$sel" | cut -d'|' -f6 | tr -d ' ')"
    ref="ghcr.io/myos-dev/${tag}"
    echo "Selected: $ref"
    echo "Executing: sudo bootc switch $ref"
    sudo bootc switch "$ref"
    echo "Workstation images re-apply the correct display-manager ownership on boot after the switch."
    echo "bootc auto-apply is disabled in myOS; reboot when you are ready to activate the new image."
