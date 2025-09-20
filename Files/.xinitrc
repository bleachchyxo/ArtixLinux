#!/bin/bash

# Load user profile
[ -f ~/.xprofile ] && . ~/.xprofile

# Start compositor if not running
pgrep -x xcompmgr > /dev/null || xcompmgr -C -t.25 -r2.2 -o.25 &

# Detect battery path
battery_path=$(find /sys/class/power_supply/ -maxdepth 1 -name "BAT*" 2>/dev/null | head -n1)

# Icon functions
get_battery_icon() {
    local level=$1
    if   [ "$level" -ge 95 ]; then echo ""
    elif [ "$level" -ge 75 ]; then echo ""
    elif [ "$level" -ge 50 ]; then echo ""
    elif [ "$level" -ge 25 ]; then echo ""
    else                          echo ""
    fi
}

get_volume_icon() {
    local volume=$1 muted=$2
    if [ "$muted" = "off" ] || [ "$volume" -eq 0 ]; then
        echo ""
    elif [ "$volume" -le 50 ]; then
        echo ""
    else
        echo ""
    fi
}

# Initialize status components
last_volume=""
last_network=""
last_battery=""
last_time=""
last_status=""

# Function to update volume status
update_volume() {
    read -r volume muted < <(
        amixer get Master | awk -F'[][]' '/%/ { gsub("%", "", $2); print $2, $4; exit }'
    )
    if [ "$volume$muted" != "$last_volume" ]; then
        volume_icon=$(get_volume_icon "$volume" "$muted")
        volume_status="$volume_icon ${volume}%"
        last_volume="$volume$muted"
        return 0
    fi
    return 1
}

# Function to update network status
update_network() {
    local new_status=" Offline"
    for iface_path in /sys/class/net/*; do
        [ -f "$iface_path/operstate" ] || continue
        local state=$(<"$iface_path/operstate")
        if [ "$state" = "up" ]; then
            iface=$(basename "$iface_path")
            if [[ "$iface" == wl* ]]; then
                new_status=" $iface"
            else
                new_status=" $iface"
            fi
            break
        fi
    done

    if [ "$new_status" != "$last_network" ]; then
        network_status="$new_status"
        last_network="$new_status"
        return 0
    fi
    return 1
}

# Function to update battery status
update_battery() {
    if [ -n "$battery_path" ]; then
        local capacity status_raw
        capacity=$(<"$battery_path/capacity")
        status_raw=$(<"$battery_path/status")
        battery_icon=$(get_battery_icon "$capacity")
        [ "$status_raw" = "Charging" ] && battery_icon="⚡$battery_icon"
        new_battery_status="$battery_icon ${capacity}%"

        if [ "$new_battery_status" != "$last_battery" ]; then
            battery_status="$new_battery_status"
            last_battery="$new_battery_status"
            return 0
        fi
    else
        battery_status=""
    fi
    return 1
}

# Function to update time every new minute
update_time() {
    local current_minute=$(date +%M)
    if [ "$current_minute" != "$last_time" ]; then
        time_status=$(date '+%-I:%M %p')
        last_time="$current_minute"
        return 0
    fi
    return 1
}

# Main loop
while true; do
    changed=0

    update_volume && changed=1
    update_network && changed=1
    update_battery && changed=1
    update_time && changed=1

    status_line=""
    [ -n "$network_status" ] && status_line+="$network_status | "
    [ -n "$battery_status" ] && status_line+="$battery_status | "
    [ -n "$volume_status" ] && status_line+="$volume_status | "
    status_line+="$time_status"

    if [ "$status_line" != "$last_status" ]; then
        xsetroot -name " $status_line "
        last_status="$status_line"
    fi

    sleep 1
done &

# Cleanup on exit
trap 'kill 0' EXIT

# Start dwm
exec dwm
