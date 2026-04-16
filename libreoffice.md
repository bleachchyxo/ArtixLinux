First edit the `mirrorlist`

    sudo nvim /etc/pacman.d/mirrorlist

and replace the contet `Server` with;

    Server = https://mirror1.artixlinux.org/$repo/os/$arch
    Server = https://mirror2.artixlinux.org/$repo/os/$arch
    Server = https://mirror3.artixlinux.org/$repo/os/$arch
    Server = https://artix.sakamoto.pl/$repo/os/$arch
    Server = https://mirror.pascalpuffke.de/artix-linux/$repo/os/$arch

Save and exit. And refresh upgrade

    sudo pacman -Syyu

Now you can install libreoffice

    sudo pacman -S libreoffice-still
