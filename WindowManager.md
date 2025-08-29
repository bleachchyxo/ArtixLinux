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

    pacman -S xorg xorg-xinit ttf-dejavu alsa-utils alsa-utils-runit

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
    [ -f ~/.xprofile ] && . ~/.xprofile

    # Paths for battery and network
    bat_path=/sys/class/power_supply/BAT0
    wifi_paths=(/sys/class/net/wlp*/operstate /sys/class/net/wlan*/operstate)
    eth_paths=(/sys/class/net/enp*/operstate /sys/class/net/eth*/operstate)

    # Function to get the first available network interface that is up
    get_network_status() {
        for path in "${wifi_paths[@]}" "${eth_paths[@]}"; do
            [ -e "$path" ] && [ "$(cat "$path")" == "up" ] && echo "Up" && return
        done
        echo "Down"
    }

    # Start your composite (xcompmgr, compton, picom)
    picom --backend egl &


    # Main loop
    while true; do
        # Volume status
        vstat="$(amixer get Master | awk -F'[][]' 'END {print $2}')"

        # Battery status (only if laptop with battery)
        if [ -e "$bat_path/capacity" ]; then
            bstat=$(<"$bat_path/capacity")
            bat_status=$(<"$bat_path/status")
            btitle="| BAT: "
            per="% "
            bend="|"
            # Charging status
            [ "$bat_status" == "Charging" ] && cstat="⚡ " || cstat=""
        else
            bstat="|"
            bat_status=""
            btitle=""
            per=""
            bend=""
            cstat=""
        fi

        # Network status (Up/Down)
        wstat=$(get_network_status)

        # Display the status on the root window (bottom bar)
        xsetroot -name " WEB: $wstat $btitle$bstat$per$cstat$bend VOL: $vstat | $(date '+%I:%M %p') "

        # Sleep for 1 second before updating
        sleep 1
    done &

    # Launch window manager
    exec dwm

## Installing suckless patches

Download the following packages;

    sudo pacman -S xcompmgr picom

Once you download these packages also download your GPU drivers, *noveau* drivers will cause errors. Download alpha patch
