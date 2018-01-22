#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "Install LinuxKit",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "Install LinuxKit. THIS IS AN EXAMPLE ONLY!",
  "options": "",
  "logoURL": "",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_linuxkit/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "https://github.com/bootrino/",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "linux",
    "linuxkit",
    "runfromram"
  ]
}
BOOTRINOJSONMARKER

setup()
{
    export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/bin
    OS=tinycore
    set +xe
    BOOT_PARTITION=/mnt/boot_partition/
    ROOT_PARTITION=/mnt/root_partition/
}

download_linuxkit()
{
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_linuxkit/
    KERNEL_NAME=linuxkit-kernel
    INITRAMFS_NAME=linuxkit-initrd.img
    cd ${BOOT_PARTITION}
    sudo wget ${URL_BASE}${KERNEL_NAME}
    sudo wget ${URL_BASE}${INITRAMFS_NAME}
}

create_syslinuxcfg()
{
# notice that we did not include bootrino_initramfs.gz on the initrd. This ensures the
# bootrino does run again on next boot, which would be a problem because if it did,
# then the install process would run over and over.
# if you did want bootrino to run, then the initrd should look like this:
#   INITRD linuxkit-initrd.img,bootrino_initramfs.gz

echo "------->>> create syslinux.cfg"
sudo sh -c 'cat > /mnt/boot_partition/syslinux.cfg' << EOF
SERIAL 0
DEFAULT operatingsystem
# on EC2 this ensures output to both VGA and serial consoles
# console=ttyS0 console=tty0
LABEL operatingsystem
    KERNEL linuxkit-kernel console=tty0 console=ttyS0 console=ttyAMA0
    INITRD linuxkit-initrd.img
EOF
}

setup
download_linuxkit
create_syslinuxcfg

#echo "REBOOT is required at this point to launch"
#echo "REBOOT is required at this point to launch" > /dev/console
#echo "REBOOT is required at this point to launch" > /dev/tty0
sudo reboot

