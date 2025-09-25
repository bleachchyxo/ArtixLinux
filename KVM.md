To install we must start by checking if your machine really support VMs

    lscpu | grep Virtualization
    grep -E 'vmx|svm' /proc/cpuinfo




    qemu libvirt libvirt-runit dnsmasq virt-manager
