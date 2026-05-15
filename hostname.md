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
