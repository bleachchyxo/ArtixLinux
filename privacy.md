    cat /etc/NetworkManager/NetworkManager.conf
content;

    # Configuration file for NetworkManager.
    # See "man 5 NetworkManager.conf" for details.

    [device]
    wifi.scan-rand-mac-address=yes

    [connection]
    ethernet.cloned-mac-address=random
    wifi.cloned-mac-address=random

`/etc/runit/sv/NetworkManager/run` content;

    #!/bin/sh
    # Reset NM identity for per-boot MAC randomization
    rm -f /var/lib/NetworkManager/secret_key
    rm -f /var/lib/NetworkManager/*lease*

    # Keep interfaces down to avoid real MAC exposure
    ip link set wlan0 down 2>/dev/null
    ip link set eth0 down 2>/dev/null

    # Randomize MAC addresses
    ip link set eth0 address $(hexdump -n 6 -v -e '/1 "%02X" 1' /dev/random)
    ip link set wlan0 address $(hexdump -n 6 -v -e '/1 "%02X" 1' /dev/random)

    # Bring the interfaces back up with the new MAC addresses
    ip link set eth0 up
    ip link set wlan0 up

    # Check that dbus is available before continuing
    sv check dbus >/dev/null || exit 1

    # Create required directories for NetworkManager
    [ ! -d /etc/NetworkManager/dispatcher.d ] && mkdir -m0755 -p /etc/NetworkManager/dispatcher.d
    [ ! -d /etc/NetworkManager/VPN ] && mkdir -m0755 -p /etc/NetworkManager/VPN
    [ ! -d /etc/NetworkManager/system-connections ] && mkdir -m0755 -p /etc/NetworkManager/system-connections
    [ ! -d /var/lib/NetworkManager ] && mkdir -m0700 -p /var/lib/NetworkManager

    # Finally, start NetworkManager
    exec NetworkManager -n > /dev/null 2>&1
