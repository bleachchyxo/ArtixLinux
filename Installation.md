# Installing Artix Linux

## Partitioning the disk
First locate your disk by typing `lsblk`


    $ lsblk
    
    NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
    sdx      8:0    0 223.6G  0 disk
     ├─sdx1   8:1    0 222.6G  0 part /
     ├─sdx2   8:2    0     1K  0 part
     └─sdx5   8:5    0   975M  0 part [SWAP]
     sr0     11:0    1  1024M  0 rom
 
We are going to start by deleting all the partitions on `sdx` using `fdisk` and creating new partitions. The first partition must be at least `+1G`, the second partition must be at least `+30G` and the last partition will be using the rest of the disk.

To be able to use these partitions we are going to create a file system on each one. If your system runs on `BIOS/Legacy` you will need to use `ext4` on each partition;

    mkfs.ext4 /dev/sdx1
    mkfs.ext4 /dev/sdx2
    mkfs.ext4 /dev/sdx3

But if your system runs on `UEFI` you basically do the same just make sure to use `FAT32` on the first partition;


    mkfs.fat -F32 /dev/sdx1
    mkfs.ext4 /dev/sdx2
    mkfs.ext4 /dev/sdx3


## Mounting directories on the partitons

Once our partitons are ready to be used we going to proceed mounting directories on the partitions

    mount /dev/sdx2 /mnt
    mkdir /mnt/home
    mkdir /mnt/boot
    mount /dev/sdx1 /mnt/boot
    mount /dev/sdx3 /mnt/home
    
Now we can check if we did everything correct by running `lsblk` and having an output similar to this

    $ lsblk
    
    NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
     sdx      8:0    0 223.6G  0 disk
     ├─sdx1   8:1    0     1G  0 part /mnt/boot
     ├─sdx2   8:2    0    30G  0 part /mnt
     └─sdx3   8:5    0 192.6G  0 part /mnt/home
     sr0     11:0    1  1024M  0 rom
    
## Installing the basics on the system

In order to install basic programs on our operative system we are going to run

    basestrap /mnt base base-devel runit elogind-runit linux linux-firmware neovim

Then in order for the system to recognize the partitions we are going to run

    fstabgen -U /mnt >> /mnt/etc/fstab
    
## Chrooting

In order to enter our system from the system we in we are going to `chroot` using the next command

    artix-chroot /mnt
    
Leaving you with a terminal prompt looking like this:

    sh-5.1#

You are going to type `bash` in order to get bash tools

## Setting our timezone

In order to set our timezone we are going to create a symbolic link

    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

If you made it correctly while running:

    $ ls -l /etc/localtime
    lrwxrwxrwx 1 root root 39 Apr 18 15:31 /etc/localtime -> /usr/share/zoneinfo/America/New_York

Then just update the hardware clock

    hwclock --systohc

## Setting locales

You are going to edit the file `/etc/locale.gen` which lists all the different aviable locales for the system, in my case english so I will uncomment `en_US.UTF-8 UTF-8` and `en_US ISO-8859-1`. Once uncommented we save the file and run the command

    locale-gen

Next we are going to create a file `/etc/locale.conf` and write on it

    LANG=en_US.UTF-8

## Installing networkmanager

    pacman -S networkmanager networkmanager-runit
    
Now we are going to set the service to run by default in order to autostart

    ln -s /etc/runit/sv/NetworkManager/ /etc/runit/runsvdir/current

once you set the `networkmanager` create the file `/etc/NetworkManager/conf.d/00-macrandomize.conf` with the following content;

    [device]
    wifi.scan-rand-mac-address=yes

    [connection]
    wifi.cloned-mac-address=stable  # Use stable MAC for each SSID
    ethernet.cloned-mac-address=stable  # Optional: for Ethernet connections

    
## Creating some system files

We are going to start giving a name to our machine/host by creating the file `/etc/hostname` and inside that file you are going to write your computers hostname.

Now we are going to edit the already existing file `/etc/hosts`

    127.0.0.1        localhost
    ::1              localhost
    127.0.1.1        myhostname.localdomain  myhostname
    
## Installing grub

For `BIOS/Legact` just install `grub`

    pacman -S grub

For `UEFI` install the following;

    pacman -S grub efibootmgr
    
To install `grub` in our disk depends again on your firmware. For `BIOS`;

    grub-install --target=i386-pc /dev/sdx

For `UEFI`;

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

Finally we are going to create a `grub` config files

    grub-mkconfig -o /boot/grub/grub.cfg
    
# Setting a password

Type `passwd` and enter you password
