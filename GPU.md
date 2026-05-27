Install gpu drivers

    sudo pacman -S nvidia-open-dkms linux-headers dkms base-devel

reboot

    lspci -k -d ::03xx
