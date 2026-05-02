`/etc/NetworkManager/conf.d/00-macrandomize.conf` content;

    [device]
    wifi.scan-rand-mac-address=yes

    [connection]
    wifi.cloned-mac-address=stable
    ethernet.cloned-mac-address=stable
    ipv6.method=disabled

`/etc/runit/sv/NetworkManager/run` content;

    #!/bin/sh

    # Ensure dbus is ready
    sv check dbus >/dev/null || exit 1

    # Reset NetworkManager identity (per-boot MAC seed)
    rm -f /var/lib/NetworkManager/secret_key

    # Prevent any early interface activity
    for i in /sys/class/net/*; do
        iface=$(basename "$i")
        [ "$iface" = "lo" ] && continue
        ip link set "$iface" down 2>/dev/null
    done

    # Create required dirs (unchanged)
    [ ! -d /etc/NetworkManager/dispatcher.d ] && mkdir -m0755 -p /etc/NetworkManager/dispatcher.d
    [ ! -d /etc/NetworkManager/VPN ] && mkdir -m0755 -p /etc/NetworkManager/VPN
    [ ! -d /etc/NetworkManager/system-connections ] && mkdir -m0755 -p /etc/NetworkManager/system-connections
    [ ! -d /var/lib/NetworkManager ] && mkdir -m0700 -p /var/lib/NetworkManager

    # Start NetworkManager
    exec NetworkManager -n > /dev/null 2>&1


Original 

    cat /etc/runit/sv/NetworkManager/run
    #!/bin/sh
    sv check dbus >/dev/null || exit 1
    # Create required dirs
    [ ! -d /etc/NetworkManager/dispatcher.d ] && mkdir -m0755 -p /etc/NetworkManager/dispatcher.d
    [ ! -d /etc/NetworkManager/VPN ] && mkdir -m0755 -p /etc/NetworkManager/VPN
    [ ! -d /etc/NetworkManager/system-connections ] && mkdir -m0755 -p /etc/NetworkManager/system-connections
    [ ! -d /var/lib/NetworkManager ] && mkdir -m0700 -p /var/lib/NetworkManager
    exec NetworkManager -n > /dev/null 2>&1


test;

    #!/bin/sh

    # Ensure dbus is ready
    sv check dbus >/dev/null || exit 1

    # Reset NetworkManager identity (per-boot MAC seed)
    rm -f /var/lib/NetworkManager/secret_key

    # Ensure required dirs exist
    [ ! -d /etc/NetworkManager/dispatcher.d ] && mkdir -m0755 -p /etc/NetworkManager/dispatcher.d
    [ ! -d /etc/NetworkManager/VPN ] && mkdir -m0755 -p /etc/NetworkManager/VPN
    [ ! -d /etc/NetworkManager/system-connections ] && mkdir -m0755 -p /etc/NetworkManager/system-connections
    [ ! -d /var/lib/NetworkManager ] && mkdir -m0700 -p /var/lib/NetworkManager

    # tep 1: unblock Wi-Fi (kernel had it blocked)
    rfkill unblock wifi 2>/dev/null

    # Step 2: bring interfaces up (they were forced down by udev)
    for i in /sys/class/net/*; do
        iface=$(basename "$i")
        [ "$iface" = "lo" ] && continue
        ip link set "$iface" up 2>/dev/null
    done

    # Start NetworkManager
    exec NetworkManager -n > /dev/null 2>&1

edit `/etc/default/grub` and change from 

    GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"

to

    GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet rfkill.default_state=0"

regenerate grub config;

    sudo grub-mkconfig -o /boot/grub/grub.cfg

create `/etc/udev/rules.d/10-net-down.rules`

    ACTION=="add", SUBSYSTEM=="net", KERNEL!="lo", ATTR{type}=="1", RUN+="/usr/bin/ip link set %k down"

reboot.
