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
    fi
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows XP Luna"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows XP'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows XP Luna"
    fi
    
# Enable Windows 7 Theme
win7:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows7"
        gsettings set org.cinnamon.desktop.interface icon-theme "Windows7"
        gsettings set org.cinnamon.theme name "Windows7"
    fi
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows7"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows7'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows7"
    fi            
    
# Enable Windows 10 Dark Theme
win10-dark:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows10-Dark"
        gsettings set org.cinnamon.desktop.interface icon-theme "Windows10"
        gsettings set org.cinnamon.theme name "Windows10-Dark"
    fi
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows10-Dark"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows10'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows10-Dark"
    fi            
    
# Enable Windows 10 Light Theme
win10-light:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "Windows10-Light"
        gsettings set org.cinnamon.desktop.interface icon-theme "Windows10"
        gsettings set org.cinnamon.theme name "Windows10-Light"
    fi
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Windows10-Light"
        gsettings set org.gnome.desktop.interface icon-theme 'Windows10'
        gsettings set org.gnome.desktop.wm.preferences theme "Windows10-Light"
     fi    
     
# Enable MacOS Dark Theme
macos-dark:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        gsettings set org.gnome.desktop.interface gtk-theme "MacOS-Dark"
        gsettings set org.gnome.desktop.interface icon-theme 'MacOS'
        gsettings set org.gnome.desktop.wm.preferences theme "MacOS-Dark"
    fi
    if [[ ${BASE_IMAGE_NAME} == 'cinnamon' ]]; then
        gsettings set org.cinnamon.desktop.interface gtk-theme "MacOS-Dark"
        gsettings set org.cinnamon.desktop.interface icon-theme "MacOS"
        gsettings set org.cinnamon.theme name "MacOS-Dark"
    fi
