#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# Activates custom dotfiles
# ags

# Removes cringe anime wallpapers
for file in /usr/share/hyprland/*.png; do
    if [[ $file == *anime*.png ]]; then
        rm "$file"
        echo "Removed: $file"
    fi
done

# Sets Themes
sed -i 's/Inherits=Adwaita/Inherits=ePapirus/' /usr/share/icons/default/index.theme 

# Removes GNOME Desktop Files
# rm /usr/share/applications/org.gnome.ColorProfileViewer.desktop
# rm /usr/share/applications/org.gnome.Settings.desktop
# rm /usr/share/applications/org.gnome.Tecla.desktop
# rm /usr/share/applications/org.gnome.Tour.desktop
