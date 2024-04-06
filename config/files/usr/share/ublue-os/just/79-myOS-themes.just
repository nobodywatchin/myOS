# vim: set ft=make :

# Enable Windows XP Theme
winxp:
    #!/usr/bin/bash
    gsettings set org.cinnamon.desktop.interface gtk-theme "Windows XP Luna"
    gsettings set org.cinnamon.desktop.interface icon-theme "WindowsXP"
    gsettings set org.cinnamon.theme name "Windows XP Luna"
    gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/bliss.jpg
    
    # Enable Windows 7 Theme
win7:
    #!/usr/bin/bash
    gsettings set org.cinnamon.desktop.interface gtk-theme "Windows7"
    gsettings set org.cinnamon.desktop.interface icon-theme "Windows7"
    gsettings set org.cinnamon.theme name "Windows7"
    gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/7.jpg
    
    # Enable Windows 10 Dark Theme
win10-dark:
    #!/usr/bin/bash
    gsettings set org.cinnamon.desktop.interface gtk-theme "Windows10-Dark"
    gsettings set org.cinnamon.desktop.interface icon-theme "Windows10"
    gsettings set org.cinnamon.theme name "Windows10-Dark"
    gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/10.jpg
    
        # Enable Windows 10 Light Theme
win10-light:
    #!/usr/bin/bash
    gsettings set org.cinnamon.desktop.interface gtk-theme "Windows10-Light"
    gsettings set org.cinnamon.desktop.interface icon-theme "Windows10"
    gsettings set org.cinnamon.theme name "Windows10-Light"
    gsettings set org.cinnamon.desktop.background picture-uri file:///usr/share/backgrounds/10.jpg
