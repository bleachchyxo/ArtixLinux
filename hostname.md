test;

    #!/bin/sh

    # Ensure dbus is ready
    sv check dbus >/dev/null || exit 1

    # Rotate NetworkManager stable-MAC seed each boot
    rm -f /var/lib/NetworkManager/secret_key

    # Required directories
    [ -d /etc/NetworkManager/dispatcher.d ] || mkdir -m0755 -p /etc/NetworkManager/dispatcher.d
    [ -d /etc/NetworkManager/VPN ] || mkdir -m0755 -p /etc/NetworkManager/VPN
    [ -d /etc/NetworkManager/system-connections ] || mkdir -m0700 -p /etc/NetworkManager/system-connections
    [ -d /var/lib/NetworkManager ] || mkdir -m0700 -p /var/lib/NetworkManager

    # Unblock Wi-Fi if rfkill blocked it
    rfkill unblock wifi 2>/dev/null

    # Generate realistic DHCP hostname
    WORDLIST=/usr/share/dict/words

    fake_host() {
        shuf -n1 "$WORDLIST" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cd 'a-z0-9-' \
        | sed 's/^-*//; s/-*$//' \
        | cut -c1-63
    }

    HOST="$(fake_host)"

    # Fallback if result is empty
    [ -n "$HOST" ] || HOST="host$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')"

    # Apply spoofed DHCP hostname to all profiles
    for UUID in $(nmcli -g UUID connection show); do
        nmcli connection modify "$UUID" ipv4.dhcp-hostname "$HOST"
        nmcli connection modify "$UUID" ipv6.dhcp-hostname "$HOST"
    done

    # Start NetworkManager
    exec NetworkManager -n >/dev/null 2>&1
