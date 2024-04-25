#!/usr/bin/bash

set -oue pipefail

# Add Staging repo
wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo

# 40 gets Ptyxis and patched Mutter
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
        vte291 \
        vte-profile
    rpm-ostree install ptyxis
    rpm-ostree override replace \
        --experimental \
        --from repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
            mutter
            
# Add Nerd Fonts
wget https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-"${FEDORA_MAJOR_VERSION}"/che-nerd-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo -O /etc/yum.repos.d/_copr_che-nerd-fonts-"${FEDORA_MAJOR_VERSION}".repo
