To install we must start by checking if your machine really support VMs

    lscpu | grep Virtualization
    grep -E 'vmx|svm' /proc/cpuinfo

Install the following packages;

    qemu libvirt libvirt-runit dnsmasq virt-manager

Give your user permissions;

    sudo usermod -aG libvirt,kvm <your_username>

set the services by default 

    sudo ln -s /etc/runit/sv/libvirtd /etc/runit/runsvdir/default
    sudo ln -s /etc/runit/sv/virtlockd /etc/runit/runsvdir/default
    sudo ln -s /etc/runit/sv/virtlogd /etc/runit/runsvdir/default
