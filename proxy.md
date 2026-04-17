first we need to install

    sudo pacamn -S tor tor-runit proxychains-ng

    sudo mkdir -p /etc/runit/sv/tor
    
    sudo tee /etc/runit/sv/tor/run > /dev/null <<'EOF'
    #!/bin/sh
    exec 2>&1
    exec tor -f /etc/tor/torrc
    EOF
    
    sudo chmod +x /etc/runit/sv/tor/run

    sudo ln -s /etc/runit/sv/tor /run/runit/service/

    sudo sv start tor
    sudo sv status tor
    sudo sv restart tor
