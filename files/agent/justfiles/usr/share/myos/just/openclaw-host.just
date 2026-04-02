[positional-arguments]
openclaw-host *args:
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo /usr/local/libexec/myos/openclaw-host "$@"

openclaw-host:
    #!/usr/bin/env bash
    set -euo pipefail

    command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    sel="$(fzf --prompt='OpenClaw host action: ' --height=18 --border --exit-0 --with-nth=2.. \
      <<< $'enable         Assign the owner role and scaffold the hosted tenant\nstatus         Show hosted OpenClaw status and endpoints\ndashboard      Print or open the hosted dashboard URL\nstart          Start the hosted OpenClaw service\nstop           Stop the hosted OpenClaw service\nrestart        Reconcile and restart the hosted OpenClaw service\ntailscale      Manage host-level Tailscale Serve exposure\nqr             Print the pairing QR for the hosted service\nsecret-set     Set or rotate one hosted secret\n')"
    [[ -n "$sel" ]] || { echo "No selection."; exit 0; }
    action="${sel%% *}"
    echo "→ Running: myos openclaw-host ${action}"
    exec myos openclaw-host "${action}"
