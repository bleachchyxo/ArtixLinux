`/etc/runit/sv/hostname/run`

    #!/bin/sh
    exec /etc/runit/hostname-script

`/etc/runit/hostname-script` content;

    #!/bin/sh

    WORDS=/usr/share/dict/words

    while :; do
        host=$(
            shuf -n1 "$WORDS" |
            tr '[:upper:]' '[:lower:]' |
            tr -cd 'a-z0-9'
        )

        [ -n "$host" ] || continue

        len=${#host}

        [ "$len" -ge 4 ] && [ "$len" -le 12 ] && break
    done

    hostname "$host"
    echo "$host" > /proc/sys/kernel/hostname

other attempt;

    #!/bin/sh

    IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
    [ -n "$IFACE" ] || exit 1

    MAC=$(cat /sys/class/net/"$IFACE"/address 2>/dev/null)
    [ -n "$MAC" ] || exit 1

    # deterministic seed from MAC
    seed=$(echo "$MAC" | cksum | awk '{print $1}')

    WORDS=/usr/share/dict/words

    # pick word deterministically based on seed
    count=$(wc -l < "$WORDS")
    index=$(( seed % count + 1 ))

    host=$(sed -n "${index}p" "$WORDS" |
           tr '[:upper:]' '[:lower:]' |
           tr -cd 'a-z0-9')

    # enforce sane hostname rules
    [ ${#host} -ge 4 ] && [ ${#host} -le 12 ] || host="node$seed"

    hostname "$host"
    echo "$host" > /etc/hostname

another attempt;

    #!/bin/sh

    WORDS=/usr/share/dict/words

    IFACE=$(ip route show default 2>/dev/null |
        awk '/default/ {print $5; exit}')

    [ -n "$IFACE" ] || exit 1

    MAC=$(cat "/sys/class/net/$IFACE/address" 2>/dev/null)
    [ -n "$MAC" ] || exit 1

    seed=$(printf '%s' "$MAC" | cksum | awk '{print $1}')

    host=$(
        awk -v seed="$seed" '
            /^[A-Za-z]+$/ {
                len=length($0)
                if (len >= 4 && len <= 12)
                    words[++n]=$0
            }
            END {
                if (n > 0)
                    print words[(seed % n) + 1]
            }
        ' "$WORDS" |
        tr '[:upper:]' '[:lower:]'
        )

    [ -n "$host" ] || host="node$seed"

    hostname "$host"
    printf '%s\n' "$host" > /etc/hostname

another attempt;

    #!/bin/sh

    WORDS=/usr/share/dict/words

    while :; do
        host=$(
            shuf -n1 "$WORDS" |
            tr '[:upper:]' '[:lower:]' |
            tr -cd 'a-z0-9'
        )

        len=${#host}

        [ "$len" -ge 4 ] &&
        [ "$len" -le 12 ] &&
        break
    done

    printf '%s\n' "$host" > /etc/hostname
    exec hostname -F /etc/hostname

lol

#!/bin/sh

WORDS=/usr/share/dict/words

while :; do
    host=$(
        shuf -n1 "$WORDS" |
        tr '[:upper:]' '[:lower:]' |
        tr -cd 'a-z0-9'
    )

    len=${#host}

    [ "$len" -ge 4 ] &&
    [ "$len" -le 12 ] &&
    break
done

printf '%s\n' "$host" > /etc/hostname
exec hostname -F /etc/hostname

kek

#!/bin/sh

WORDS=/usr/share/dict/words

while :; do
    host=$(
        awk '
            /^[A-Za-z]{4,12}$/ {
                print tolower($0)
            }
        ' "$WORDS" |
        shuf -n1
    )

    [ -n "$host" ] && break
done

printf '%s\n' "$host" > /etc/hostname
exec hostname -F /etc/hostname

another other attempt;

#!/bin/sh

WORDS=/usr/share/dict/words

host=$(
    awk '
        /^[A-Za-z]+$/ {
            len = length($0)

            if (len >= 4 && len <= 12)
                print tolower($0)
        }
    ' "$WORDS" | shuf -n1
)

[ -n "$host" ] || exit 1

printf '%s\n' "$host" > /etc/hostname
exec hostname -F /etc/hostname

idek anymore;

#!/bin/sh
set -eu

host=$(
    awk '
        /^[A-Za-z]+$/ {
            len = length($0)
            if (len >= 4 && len <= 12)
                print tolower($0)
        }
    ' /usr/share/dict/words |
    shuf -n1
)

hostname "$host"
printf '%s\n' "$host" > /etc/hostname

# KEKE

Create:

/etc/runit/dhcp-hostname
#!/bin/sh
set -eu

STATE=/run/dhcp-hostname
WORDS=/usr/share/dict/words

[ -f "$STATE" ] && exit 0

host=$(
    awk '
        /^[A-Za-z]+$/ {
            len = length($0)

            if (len >= 5 && len <= 10)
                print tolower($0)
        }
    ' "$WORDS" |
    shuf -n1
)

printf '%s\n' "${host:-node}" > "$STATE"
chmod 644 "$STATE"

Make executable:

chmod +x /etc/runit/dhcp-hostname
Why this is good

This filters to:

alphabetic only
lowercase only
realistic human words
medium-length hostnames
no symbols
no apostrophes
no whitespace
no bizarre entropy

Examples:

harbor
lantern
silver
falcon
meadow
vertex
apollo
ember

These look normal on networks.

Not suspicious.

Not obviously randomized.

Step 2 — Run once at boot

Create runit service:

/etc/runit/sv/dhcp-hostname/run
#!/bin/sh
exec /etc/runit/dhcp-hostname

Enable it.

Step 3 — Feed DHCP only

Now depends on DHCP stack.

OPTION A — dhcpcd (very common, very clean)

Edit:

/etc/dhcpcd.conf

Add:

hostname $(cat /run/dhcp-hostname)

But dhcpcd config is not shell-expanded.

So instead use hook.

Create:

/lib/dhcpcd/dhcpcd-hooks/20-hostname
#!/bin/sh

if [ -f /run/dhcp-hostname ]; then
    new_hostname=$(cat /run/dhcp-hostname)
fi

Actually even cleaner:

hostname

and export:

export hostname="$(cat /run/dhcp-hostname)"

before dhcpcd starts.

But honestly dhcpcd gets annoying here.

OPTION B — NetworkManager (easier)

Create dispatcher script:

/etc/NetworkManager/dispatcher.d/10-dhcp-hostname
#!/bin/sh

[ -f /run/dhcp-hostname ] || exit 0

host=$(cat /run/dhcp-hostname)

nmcli connection modify "$CONNECTION_UUID" ipv4.dhcp-hostname "$host"

But modifying every reconnect is ugly.

OPTION C — systemd-networkd (best architecture)

If you're willing to use it.

[DHCPv4]
Hostname=%H

then override transiently.

But this touches transient hostname machinery.

The actually best minimalist answer

Instead of realistic random words:

Use a generic OEM-style hostname.

Example generator:

printf 'android-%04x\n' $((RANDOM % 65536))

or:

printf 'DESKTOP-%06X\n' $((RANDOM % 16777215))

Why?

Because realistic dictionaries can still look unusual statistically.

Generic OEM patterns blend into networks better.

Examples:

android-4f2a
DESKTOP-A91C2F
thinkpad-82d1
ubuntu-7ac3

These are common and low-signal.

Privacy reality

Best stealth ranking:

no hostname
generic OEM hostname
realistic dictionary hostname
high-entropy random hostname

So if your goal is not raising flags:

DESKTOP-XXXXXX

is actually better than:

meadow

because admins see thousands of those.

Final recommendation

If you want the cleanest Unix solution:

Keep system hostname fixed

Example:

void
Generate ephemeral DHCP hostname into:
/run/dhcp-hostname
Configure DHCP client only to use it
Never mutate kernel hostname

Never use:

hostname

Never write:

/etc/hostname

Never touch:

/proc/sys/kernel/hostname

That separation is the elegant part.


