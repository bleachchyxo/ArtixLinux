#!/bin/bash

# Load profile if exists
[ -f ~/.xprofile ] && . ~/.xprofile

# Start compositor (only if not running)
pgrep -x xcompmgr > /dev/null || xcompmgr -C -t.25 -r2.2 -o.25 &

# Battery detection (if exists)
bat_path=$(find /sys/class/power_supply/ -maxdepth 1 -name "BAT*" 2>/dev/null | head -n1)

# Initial values
last_vol=""
last_net=""
last_bat=""
last_min=""

# Get battery icon based on percentage
get_battery_icon() {
    local level=$1
    if   [ "$level" -ge 95 ]; then echo ""
    elif [ "$level" -ge 75 ]; then echo ""
    elif [ "$level" -ge 50 ]; then echo ""
    elif [ "$level" -ge 25 ]; then echo ""
    else                          echo ""
    fi
}

# Get volume icon
get_vol_icon() {
    local vol=$1 muted=$2
    if [ "$muted" = "off" ] || [ "$vol" -eq 0 ]; then
        echo ""
    elif [ "$vol" -le 50 ]; then
        echo ""
    else
        echo ""
    fi
}

# Main loop
while :; do
    status=""

    ## TIME: Update only once per minute
    now_min=$(date +%M)
    if [ "$now_min" != "$last_min" ]; then
        time_str=$(date '+%-I:%M %p')
        last_min="$now_min"
    fi

    ## VOLUME: Check only if changed
    read -r vol muted < <(
        amixer get Master | awk -F'[][]' '/%/ { vol=$2; mute=$4; gsub("%","",vol); print vol, mute; exit }'
    )
    if [ "$vol$muted" != "$last_vol" ]; then
        vol_icon=$(get_vol_icon "$vol" "$muted")
        vol_str="$vol_icon ${vol}%"
        last_vol="$vol$muted"
    fi

    ## NETWORK: Check only if state changes
    net_status=" Offline"
    for iface in /sys/class/net/*; do
        [ -f "$iface/operstate" ] || continue
        state=$(<"$iface/operstate")
        if [ "$state" = "up" ]; then
            if [[ "$iface" == *"wl"* ]]; then
                icon=""
            else
                icon=""
            fi
            name=${iface##*/}
            net_status="$icon $name"
            break
        fi
    done
    if [ "$net_status" != "$last_net" ]; then
        net_str="$net_status"
        last_net="$net_status"
    fi

    ## BATTERY: Only if exists and value changes
    if [ -n "$bat_path" ]; then
        read -r capacity < "$bat_path/capacity"
        read -r status_raw < "$bat_path/status"
        bicon=$(get_battery_icon "$capacity")
        [ "$status_raw" = "Charging" ] && bicon="⚡$bicon"
        bat_str="$bicon ${capacity}%"
        if [ "$bat_str" != "$last_bat" ]; then
            last_bat="$bat_str"
        fi
    else
        bat_str=""
    fi

    ## Assemble final status line
    status=""
    [ -n "$net_str" ] && status+="$net_str | "
    [ -n "$bat_str" ] && status+="$bat_str | "
    [ -n "$vol_str" ] && status+="$vol_str | "
    status+="$time_str"

    xsetroot -name " $status "

    sleep 5
done &

# Cleanup children on exit
trap 'kill 0' EXIT

# Start DWM
exec dwm
