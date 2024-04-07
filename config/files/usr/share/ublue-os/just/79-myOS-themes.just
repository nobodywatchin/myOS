# vim: set ft=make :

# Enable Windows XP Theme
winxp:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows XP Luna"
        gsettings set org.cinnamon.desktop.interface icon-theme "WindowsXP"
        gsettings set org.cinnamon.theme name "Windows XP Luna"
        gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/bliss.jpg
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows XP Luna"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows XP'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows XP Luna"
        
    # Enable Windows 7 Theme
win7:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows7"
        gsettings set org.cinnamon.desktop.interface icon-theme "Windows7"
        gsettings set org.cinnamon.theme name "Windows7"
        gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/7.jpg
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows7"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows7'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows7"
        
    # Enable Windows 10 Dark Theme
win10-dark:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows10-Dark"
        gsettings set org.cinnamon.desktop.interface icon-theme "Windows10"
        gsettings set org.cinnamon.theme name "Windows10-Dark"
        gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/10.jpg
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows10-Dark"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows10'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows10-Dark"
        
    # Enable Windows 10 Light Theme
win10-light:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows10-Light"
        gsettings set org.cinnamon.desktop.interface icon-theme "Windows10"
        gsettings set org.cinnamon.theme name "Windows10-Light"
        gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/10.jpg
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows10-Light"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows10'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows10-Light"
        
    # Enable MacOS Dark Theme
macos-dark:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "MacOS-Dark"
        gsettings set org.gnome.desktop.interface icon-theme 'MacOS'
        gsettings set org.gnome.desktop.wm.preferences theme "MacOS-Dark"
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "MacOS-Dark"
        gsettings set org.cinnamon.desktop.interface icon-theme "MacOS"
        gsettings set org.cinnamon.theme name "MacOS-Dark"
        gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/sonoma.jpg
    fi

    # Enable MacOS Light Theme
macos-dark:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "MacOS-Light"
        gsettings set org.gnome.desktop.interface icon-theme 'MacOS'
        gsettings set org.gnome.desktop.wm.preferences theme "MacOS-Light"
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "MacOS-Light"
        gsettings set org.cinnamon.desktop.interface icon-theme "MacOS"
        gsettings set org.cinnamon.theme name "MacOS-Light"
        gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/sonoma.jpg
    fi
