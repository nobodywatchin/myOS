# vim: set ft=make :

# Restore myOS customized DE settings
restore-myos-gnome-settings:
    dconf load / < /usr/etc/dconf/db/local.d/02-myos-global
    dconf load / < /usr/etc/dconf/db/local.d/03-myos-dash
    dconf load / < /usr/etc/dconf/db/local.d/05-myos-extensions
    dconf load / < /usr/etc/dconf/db/local.d/06-myos-theme

# Restore myOS customized applications folders
organize-apps:
    dconf load / < /usr/etc/dconf/db/local.d/04-myos-folders
