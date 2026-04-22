    [device]
    wifi.scan-rand-mac-address=yes

    [connection]
    wifi.cloned-mac-address=stable
    ethernet.cloned-mac-address=stable

This ensures:

- MAC is consistent while connected
- LAN (like Minecraft) works reliably
- no constant reconnect issues

      sudo nvim /etc/runit/sv/NetworkManager/run

and add this:

    # Reset NM identity for per-boot MAC randomization
    rm -f /var/lib/NetworkManager/secret_key
    rm -f /var/lib/NetworkManager/*lease*

    # Keep interfaces down to avoid real MAC exposure
    ip link set wlan0 down 2>/dev/null
    ip link set eth0 down 2>/dev/null

should look like this;

    #!/bin/sh

    # Reset NM identity for per-boot MAC randomization
    rm -f /var/lib/NetworkManager/secret_key
    rm -f /var/lib/NetworkManager/*lease*

    # Prevent early MAC leaks
    ip link set wlan0 down 2>/dev/null
    ip link set eth0 down 2>/dev/null

    sv check dbus >/dev/null || exit 1

    # Create required dirs
    [ ! -d /etc/NetworkManager/dispatcher.d ] && mkdir -m0755 -p /etc/NetworkManager/dispatcher.d
    [ ! -d /etc/NetworkManager/VPN ] && mkdir -m0755 -p /etc/NetworkManager/VPN
    [ ! -d /etc/NetworkManager/system-connections ] && mkdir -m0755 -p /etc/NetworkManager/system-connections
    [ ! -d /var/lib/NetworkManager ] && mkdir -m0700 -p /var/lib/NetworkManager

    exec NetworkManager -n > /dev/null 2>&1
