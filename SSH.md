Install

    sudo pacman -S openssh openssh-runit
    
Enable the sshd service:

    sudo ln -s /etc/runit/sv/sshd /run/runit/service/

Check service status:

    sudo sv status sshd
    
You should see output like:

    run: sshd: (pid 5854) 15s

Start the service immediately (if it's not already running):

    sudo sv up sshd

