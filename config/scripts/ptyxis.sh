#!/usr/bin/bash

set -oue pipefail

# Add Staging repo
wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-40/ublue-os-staging-fedora-40.repo -O /etc/yum.repos.d/ublue-os-staging-fedora-40.repo

# 40 gets Ptyxis and patched Mutter
  #  rpm-ostree override replace \
  #  --experimental \
  #  --from repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
  #      vte291 \
  #      vte-profile
  #  rpm-ostree install ptyxis
            
# Add Nerd Fonts
wget https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-40/che-nerd-fonts-fedora-40.repo -O /etc/yum.repos.d/_copr_che-nerd-fonts-40.repo
