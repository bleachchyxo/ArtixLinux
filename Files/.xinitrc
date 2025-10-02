#!/bin/sh

# Load user profile if it exists
[ -f ~/.xprofile ] && . ~/.xprofile

# Start compositor if not already running
pgrep -x xcompmgr >/dev/null || xcompmgr -C -t.25 -r2.2 -o.25 &

# Find battery path (once)
battery=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' 2>/dev/null | head -n1)

# Battery icon function
battery_icon() {
  case $1 in
    9[5-9]|100) echo "";;
    7[5-9]|8[0-9]|9[0-4]) echo "";;
    5[0-9]|6[0-9]|7[0-4]) echo "";;
    2[5-9]|3[0-9]|4[0-9]) echo "";;
    *) echo "";;
  esac
}

# Volume icon function
volume_icon() {
  [ "$2" = "off" ] || [ "$1" -eq 0 ] && echo "" && return
  [ "$1" -le 50 ] && echo "" && return
  echo ""
}

# Initial values to track changes
last_status=""
last_battery_status=""

# Trap to clean up background processes
trap 'kill 0' EXIT

# Main loop
while :; do
  # Volume
  set -- $(amixer get Master | awk -F'[][]' '/Mono:/||/Left:/ {gsub("%",""); print $2, $6; exit} /Playback.*%/ {gsub("%",""); print $2, $4; exit}')
  vol_icon=$(volume_icon "$1" "$2")
  vol_status="$vol_icon $([ "$2" = "off" ] || [ "$1" -eq 0 ] && echo "Muted" || echo "$1%")"

  # Network
  net_status=" Offline"
  for iface in /sys/class/net/*; do
    [ -f "$iface/operstate" ] || continue
    state=$(cat "$iface/operstate")
    [ "$state" = "up" ] || continue
    name=$(basename "$iface")
    case "$name" in
      wl*) net_status=" $name"; break;;
      *) net_status=" $name"; break;;
    esac
  done

  # Battery
  battery_status=""
  if [ "$battery" ]; then
    cap=$(cat "$battery/capacity")
    state=$(cat "$battery/status")
    icon=$(battery_icon "$cap")
    [ "$state" = "Charging" ] && icon="⚡$icon"
    battery_status="$icon $cap%"

    # Low battery warning
    if [ "$cap" -le 30 ] && [ "$battery_status" != "$last_battery_status" ]; then
      beep -f 550 -l 200 -n -d 50 -f 440 -l 300
      notify-send "Low Battery" "Battery level is at $cap%. Please charge your device."
      last_battery_status="$battery_status"
    fi
  fi

  # Time (only update on new minute)
  minute=$(date +%M)
  if [ "$minute" != "$last_minute" ]; then
    time_status=$(date '+%-I:%M %p')
    last_minute="$minute"
  fi

  # Combine full status line
  status=" $net_status${battery_status:+ | $battery_status} | $vol_status | $time_status "

  # Only update if changed
  [ "$status" != "$last_status" ] && xsetroot -name "$status" && last_status="$status"

  sleep 1
done &

# Startup beep and start dwm
beep -f 1046 -l 40 -n -d 30 -f 1318 -l 400 & exec dwm
