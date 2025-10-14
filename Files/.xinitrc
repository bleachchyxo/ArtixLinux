#!/bin/sh

[ -f ~/.xprofile ] && . ~/.xprofile

pgrep -x xcompmgr >/dev/null || xcompmgr -C -t.25 -r2.2 -o.25 &

trap 'kill 0' EXIT

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

last_minute=""
last_volume=""
last_network=""
last_battery=""
last_battery_warn=""

while :; do
  changed=0

  # Time: update once per minute
  minute=$(date +%M)
  if [ "$minute" != "$last_minute" ]; then
    time_status=$(date '+%-I:%M %p')
    last_minute="$minute"
    changed=1
  fi

  # Volume: show only if 'amixer get Master' outputs a volume percentage
  if amixer get Master | grep -q '%'; then
    set -- $(amixer get Master | awk -F'[][]' '/Mono:/||/Left:/ {gsub("%",""); print $2, $6; exit} /Playback.*%/ {gsub("%",""); print $2, $4; exit}')
    icon=$(volume_icon "$1" "$2")
    volume_status="$icon"
    [ "$2" = "off" ] && volume_status="$icon Muted"
    [ "$1" -eq 0 ] && [ "$2" != "off" ] && volume_status="$icon 0%"
    [ "$1" -gt 0 ] && [ "$2" != "off" ] && volume_status="$icon $1%"

    if [ "$volume_status" != "$last_volume" ]; then
      last_volume="$volume_status"
      changed=1
    fi
  else
    volume_status=""
    last_volume=""
  fi

  # Network: update only on change
  network_status=" Offline"
  for iface in /sys/class/net/*; do
    [ -f "$iface/operstate" ] || continue
    [ "$(cat "$iface/operstate")" = "up" ] || continue
    name=$(basename "$iface")
    case "$name" in
      wl*) network_status=" $name"; break ;;
      *)   network_status=" $name"; break ;;
    esac
  done
  if [ "$network_status" != "$last_network" ]; then
    last_network="$network_status"
    changed=1
  fi

  # Battery: update only on change, send notification on low battery once per warning
  battery_status=""
  for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    cap=$(cat "$bat/capacity")
    stat=$(cat "$bat/status")
    icon=$(battery_icon "$cap")
    [ "$stat" = "Charging" ] && icon="⚡$icon"
    battery_status="$icon $cap%"
    if [ "$cap" -le 30 ] && [ "$battery_status" != "$last_battery_warn" ]; then
      notify-send "Low Battery" "Battery at $cap%. Please charge."
      last_battery_warn="$battery_status"
    fi
    break
  done
  if [ "$battery_status" != "$last_battery" ]; then
    last_battery="$battery_status"
    changed=1
  fi

  # Build status line with only present info
  status=" $last_network"
  [ -n "$last_battery" ] && status="$status | $last_battery"
  [ -n "$last_volume" ] && status="$status | $last_volume"
  status="$status | $time_status "

  [ "$changed" -eq 1 ] && xsetroot -name "$status"

  sleep 1
done &

exec dwm
