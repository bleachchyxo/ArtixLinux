## SSH from host machine → Debian VM

Inside the Debian VM

    ip a

Look for an ip like `inet 192.168.122.100/24`. If you see something in the `192.168.122.x` range, good news! it’s using the default libvirt NAT network `virbr0`.

In the Debian VM terminal:

    sudo apt update
    sudo apt install openssh-server -y
    sudo systemctl enable ssh
    sudo systemctl start ssh
    
Check it's running:

    sudo systemctl status ssh

## Step-by-Step: Set Up Port Forwarding on Artix (host)

Check if foward port it's enabled:

    cat /proc/sys/net/ipv4/ip_forward

If it returns `0`, enable it temporarily:

    sudo sysctl -w net.ipv4.ip_forward=1

To make it permanent, add to `/etc/sysctl.d/99-sysctl.conf` or create it if it doesn’t exist;

    net.ipv4.ip_forward = 1

## Apply immediately without reboot:

    sudo sysctl --system

OR 

    sudo sysctl -w net.ipv4.ip_forward=1

Confirm it worked:

    cat /proc/sys/net/ipv4/ip_forward
    
should return `1`.


