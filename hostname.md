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
