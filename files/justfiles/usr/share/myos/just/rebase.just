REGISTRY := env_var("REGISTRY", "ghcr.io")
OWNER    := env_var("OWNER", "nobodywatchin")

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

rebase:
    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$(
        printf '%s\n' \
        fedora42:latest \
        fedora42-nvidia:latest \
        alma10:latest \
        alma10-nvidia:latest \
        alma9:latest \
        alma9-nvidia:latest \
        | fzf --prompt='Select image: '
    )"

    test -n "$sel" || { echo "No image selected"; exit 1; }

    ref="{{REGISTRY}}/{{OWNER}}/${sel}"
    echo "Selected: $ref"
    echo "Executing: sudo bootc switch $ref"
    sudo bootc switch "$ref"
    echo "Done. Reboot when ready."
