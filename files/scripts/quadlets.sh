#!/usr/bin/env bash

set -ouex pipefail

# Make systemd targets 
mkdir -p /usr/lib/systemd/user
QUADLET_TARGETS=(
    "dockge"
)
for i in "${QUADLET_TARGETS[@]}"
do
cat > "/usr/lib/systemd/user/${i}.target" <<EOF
[Unit]
Description=${i}"target for ${i} quadlet

[Install]
WantedBy=default.target
EOF

# Have autostart tied to systemd targets
printf "\n\n[Install]\nWantedBy=%s.target" "$i" >> /etc/containers/systemd/users/"$i".container
done
