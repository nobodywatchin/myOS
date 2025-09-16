# vim: set ft=make :

# Enable Supergfxctl, a GPU switcher for hybrid laptops
enable-supergfxctl:
    systemctl enable --now supergfxd.service

# Set nvidia kargs
set-kargs-nvidia:
    rpm-ostree kargs \
      --append-if-missing=rd.driver.blacklist=nouveau \
      --append-if-missing=modprobe.blacklist=nouveau \
      --append-if-missing=nvidia-drm.modeset=1 \
      --append-if-missing=nvidia-drm.fbdev=1

# Remove nvidia kargs
remove-kargs-nvidia:
    rpm-ostree kargs \
      --delete-if-present=rd.driver.blacklist=nouveau \
      --delete-if-present=modprobe.blacklist=nouveau \
      --delete-if-present=nvidia-drm.modeset=1 \
      --delete-if-present=nvidia-drm.fbdev=1
