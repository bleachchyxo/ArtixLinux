#!/bin/sh

[ -f ~/.xprofile ] && . ~/.xprofile

pgrep -x xcompmgr >/dev/null || xcompmgr -C -t.25 -r2.2 -o.25 &

# Icons
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
  [ "$2" = "off" ] || [ "$1" -eq 0 ] && echo "" && return
  [ "$1" -le 50 ] && echo "" && return
  echo ""
}

trap 'kill 0' EXIT

# State variables
last_time=""
last_volume=""
last_network=""
last_battery=""
last_battery_warn=""
last_minute=""
last_net_iface=""

# Interval tracking
last_battery_check=0
last_network_check=0

while :; do
  changed=0
  now=$(date +%s)

  #### TIME MODULE ####
  current_minute=$(date +%M)
  if [ "$current_minute" != "$last_minute" ]; then
    time_status=$(date '+%-I:%M %p')
    last_minute="$current_minute"
    changed=1
  fi

  #### VOLUME MODULE ####
  set -- $(amixer get Master | awk -F'[][]' '/Mono:/||/Left:/ {gsub("%",""); print $2, $6; exit} /Playback.*%/ {gsub("%",""); print $2, $4; exit}')
  volume_icon=$(volume_icon "$1" "$2")
  volume_status="$volume_icon $([ "$2" = "off" ] || [ "$1" -eq 0 ] && echo "Muted" || echo "$1%")"

  [ "$volume_status" != "$last_volume" ] && {
    last_volume="$volume_status"
    changed=1
  }

  #### NETWORK MODULE ####
  if [ $((now - last_network_check)) -ge 10 ]; then
    net_status=" Offline"
    for iface in /sys/class/net/*; do
      [ -f "$iface/operstate" ] || continue
      state=$(cat "$iface/operstate")
      [ "$state" = "up" ] || continue
      iface_name=$(basename "$iface")
      net_status=" $iface_name"
      case "$iface_name" in
        wl*) net_status=" $iface_name"; break ;;
        *)   net_status=" $iface_name"; break ;;
      esac
    done
    [ "$net_status" != "$last_network" ] && {
      last_network="$net_status"
      changed=1
    }
    last_network_check=$now
  fi

  #### BATTERY MODULE ####
  if [ $((now - last_battery_check)) -ge 15 ]; then
    battery_status=""
    for battery_path in /sys/class/power_supply/BAT*; do
      [ -d "$battery_path" ] || continue
      capacity=$(cat "$battery_path/capacity")
      status=$(cat "$battery_path/status")
      icon=$(battery_icon "$capacity")
      [ "$status" = "Charging" ] && icon="⚡$icon"
      battery_status="$icon $capacity%"

      if [ "$capacity" -le 30 ] && [ "$battery_status" != "$last_battery_warn" ]; then
        beep -f 550 -l 200 -n -d 50 -f 440 -l 300
        notify-send "Low Battery" "Battery at $capacity%. Please charge."
        last_battery_warn="$battery_status"
      fi
      break
    done
    [ "$battery_status" != "$last_battery" ] && {
      last_battery="$battery_status"
      changed=1
    }
    last_battery_check=$now
  fi

  #### COMBINE AND DISPLAY STATUS ####
  status=" $last_network${last_battery:+ | $last_battery} | $last_volume | $time_status "

  [ "$changed" -eq 1 ] && xsetroot -name "$status"

  sleep 1
done &

# Startup sound and launch DWM
beep -f 1046 -l 40 -n -d 30 -f 1318 -l 400 &
exec dwm
