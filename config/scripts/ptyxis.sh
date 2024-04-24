#!/usr/bin/bash

set -oue pipefail

# Add Staging repo
wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-39/ublue-os-staging-fedora-39.repo -O /etc/yum.repos.d/ublue-os-staging-fedora-39.repo

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
