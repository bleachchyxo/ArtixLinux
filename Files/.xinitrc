#!/bin/sh

[ -f ~/.xprofile ] && . ~/.xprofile

pgrep -x xcompmgr >/dev/null || xcompmgr -C -t.25 -r2.2 -o.25 &

trap 'kill 0' EXIT

# === One-time checks ===

# Volume support check
volume_enabled=1
amixer >/dev/null 2>&1 || volume_enabled=0

battery_icon() {
  case $1 in
    9[5-9]|100) echo "";;
    7[5-9]|8[0-9]|9[0-4]) echo "";;
    5[0-9]|6[0-9]|7[0-4]) echo "";;
    2[5-9]|3[0-9]|4[0-9]) echo "";;
    *) echo "";;
  esac
}

volume_icon() {
  [ "$2" = "off" ] && echo "" && return
  [ "$1" -eq 0 ] && echo "" && return
  [ "$1" -le 50 ] && echo "" && return
  echo ""
}

last_time=""
last_volume=""
last_network=""
last_battery=""
last_battery_warn=""
last_minute=""

while :; do
  changed=0
  now=$(date +%s)

  #### TIME ####
  minute=$(date +%M)
  if [ "$minute" != "$last_minute" ]; then
    time_status=$(date '+%-I:%M %p')
    last_minute="$minute"
    changed=1
  fi

  #### VOLUME ####
  if [ "$volume_enabled" -eq 1 ]; then
    read volume mute <<< $(amixer get Master | awk -F'[][]' '/Mono:/||/Left:/ {gsub("%",""); print $2, $6; exit} /Playback.*%/ {gsub("%",""); print $2, $4; exit}')
    icon=$(volume_icon "$volume" "$mute")

    if [ "$mute" = "off" ]; then
      volume_status="$icon Muted"
    elif [ "$volume" -eq 0 ]; then
      volume_status="$icon 0%"
    else
      volume_status="$icon $volume%"
    fi

    [ "$volume_status" != "$last_volume" ] && {
      last_volume="$volume_status"
      changed=1
    }
  else
    volume_status=""
    [ "$last_volume" != "" ] && {
      last_volume=""
      changed=1
    }
  fi

  #### NETWORK ####
  network_status=" Offline"
  for iface in /sys/class/net/*; do
    [ -f "$iface/operstate" ] || continue
    state=$(cat "$iface/operstate")
    [ "$state" = "up" ] || continue
    name=$(basename "$iface")
    case "$name" in
      wl*) network_status=" $name"; break ;;
      *)   network_status=" $name"; break ;;
    esac
  done

  [ "$network_status" != "$last_network" ] && {
    last_network="$network_status"
    changed=1
  }

  #### BATTERY ####
  battery_status=""
  for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    cap=$(cat "$bat/capacity")
    stat=$(cat "$bat/status")
    icon=$(battery_icon "$cap")
    [ "$stat" = "Charging" ] && icon="⚡$icon"
    battery_status="$icon $cap%"

    if [ "$cap" -le 30 ] && [ "$battery_status" != "$last_battery_warn" ]; then
      beep -f 550 -l 200 -n -d 50 -f 440 -l 300
      notify-send "Low Battery" "Battery at $cap%. Please charge."
      last_battery_warn="$battery_status"
    fi
    break
  done

  [ "$battery_status" != "$last_battery" ] && {
    last_battery="$battery_status"
    changed=1
  }

  #### SET STATUS ####
  status=" $last_network${last_battery:+ | $last_battery}${last_volume:+ | $last_volume} | $time_status "

  [ "$changed" -eq 1 ] && xsetroot -name "$status"

  sleep 1
done &

# Startup sound and DWM
beep -f 1046 -l 40 -n -d 30 -f 1318 -l 400 &
exec dwm
