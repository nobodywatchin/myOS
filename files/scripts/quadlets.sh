#!/usr/bin/env bash

set -ouex pipefail

# Make systemd targets 
QUADLET_TARGETS=(
    "dockge"
)
for i in "${QUADLET_TARGETS[@]}"
do
cat > "/usr/lib/systemd/${i}.target" <<EOF
[Unit]
Description=${i}"target for ${i} quadlet

[Install]
WantedBy=default.target
EOF

# Have autostart tied to systemd targets
printf "\n\n[Install]\nWantedBy=%s.target" "$i" >> /etc/containers/systemd/"$i".container
done
