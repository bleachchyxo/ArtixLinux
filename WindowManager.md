Start making the `non root` user and giving the permisions to it's own directory

    useradd <username>
    mkdir /home/<username>
    chown <username>:<username> /home/<username>

Update you machine

    pacman -Syyu

Install the `gcc` compiler

    pacman -S gcc

Now we proceed to install important packages;

    libx11 libxinerama libxft git

## Installing and compiling suckless

On your `/home/user` shouln't be any directoy yet, maybe just a couple of hidden files you can see by typing `ls -a` like `.bashrc` but nothing relevant. If so, all linux distros have a hidden config folder on this path, so we must create it

    mkdir .config

Now you `cd` on this new directoy, here we will store all our config files from most of our programs.

    git clone https://git.suckless.org/dwm 
    git clone https://git.suckless.org/dmenu 
    git clone https://git.suckless.org/st

Next thing is to `cd` into each generated directories and do the following;

    make install

Once you finished compiling those three folders want to exit from the `.config` folder and create the starting file;

    cd
    echo "exec dwm" >> ~/.xinitrc

### Installing the last packages

    pacman -S xorg xorg-xinit ttf-dejavu ttf-font-awesome alsa-utils alsa-utils-runit

### Making ALSA service start after rebooting

    ln -s /etc/runit/sv/alsa /etc/runit/runsvdir/default/

### Initiating suckless by default

    vim ~/.bash_profile

Paste the following script inside the file;

    if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
        startx
    fi

Now reboot and enjoy!

# Rice your setup

In order to do some tweaking to your setup we are going to let's start by your `.xinitrc` file;

    #!/bin/bash

    # Load profile if exists
    [-f ~/.xprofile ] && . ~/.xprofile

    # Start compositor
    xcompmgr -C -t.25 -r2.2 -o.25 &
    #picom --backend egl &

    # Battery path (only set once)
    bat_path=$(find /sys/class/power_supply/ -maxdepth 1 -name "BAT*" 2>/dev/null | head -n1)

    i=0

    while true; do
        (( i % 5 == 0 )) && vol="VOL: $(amixer get Master | awk -F'[][]' '/%/ { print $2; exit }')"

        if (( i % 15 == 0 )); then
            net="WEB: Down"
            for iface in /sys/class/net/*; do
                [ "$(cat "$iface/operstate" 2>/dev/null)" = "up" ] && net="WEB: Up" && break
            done
        fi

        if (( i % 30 == 0 )) && [ -n "$bat_path" ]; then
            read -r bstat < "$bat_path/capacity"
            read -r bstatus < "$bat_path/status"
            bicon=$([ "$bstatus" = "Charging" ] && echo "⚡")
            bat="BAT: $bstat% $bicon"
        elif [ -z "$bat_path" ]; then
            bat=""
        fi

        time_str="$(date '+%-I:%M %p')"

        # Build status string without extra pipes
        status="$net"
        [ -n "$bat" ] && status+=" | $bat"
        status+=" | $vol | $time_str"

        xsetroot -name " $status "

        sleep 1
        ((i++))
    done &

    trap 'kill 0' EXIT
    exec dwm

## Installing suckless patches

Download the following packages;

    sudo pacman -S xcompmgr picom

Once you download these packages also download your GPU drivers, *noveau* drivers will cause errors.
Install the `alpha` st patch and now we going to create a file on `.config/picom/picom.conf'


    # OPACITY

    inactive-opacity = 0.8;
    frame-opacity = 0.7;

    # ROUND CORNERS

    corner-radius = 15

    rounded-corners-exclude = [
      "class_g = 'dwm'",
      "class_g = 'dmenu'"
    ];

    # BLUR

    blur:
    {
            method = "dual_kawase";
            size = 10;
            strenght = 3;
    };

    blur-background = true

    blur-background-fixed = true

    backend = "egl"
    #backend = "glx"
