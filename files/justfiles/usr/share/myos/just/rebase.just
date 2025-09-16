REGISTRY := env("REGISTRY", "ghcr.io")
OWNER    := env("OWNER", "nobodywatchin")

set shell := ["bash", "-euo", "pipefail", "-c"]

# Interactive rebase from a fixed list of images
rebase:
    @command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    # Hardcoded list of images
    @sel="$$(printf '%s\n' \
        alma10-testing-server:latest \
        alma10-testing-server-nvidia:latest \
        alma10-testing-workstation:latest \
        alma10-testing-workstation-nvidia:latest \
        alma9-testing-server:latest \
        alma9-testing-server-nvidia:latest \
        alma9-testing-workstation:latest \
        alma9-testing-workstation-nvidia:latest \
        | fzf --prompt='Select image: ')"

    @test -n "$$sel" || { echo "No image selected"; exit 1; }

    @ref="{{REGISTRY}}/{{OWNER}}/$$sel"
    @echo "Selected: $$ref"
    @echo "Executing: sudo bootc switch $$ref"
    @sudo bootc switch "$$ref"
    @echo "Done. Reboot when ready."
