# Wine
With [Wine](https://www.winehq.org/) you can run windows apps on linux

## Installing wine

To install wine we need to edit the `/etc/pacman.conf` file and uncomment the `lib32` repo

    [lib32]
    Include = /etc/pacman.d/mirrorlist

Update your machine

    sudo pacman -Syyu

Once you updated the enabled repository you can install `wine` as you would normally do it along with it's dependencies.

    sudo pacman -S wine-staging winetricks
    sudo pacman -S giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader cups samba dosbox

You can check which `wine` version you installed by running;

    wine --version

