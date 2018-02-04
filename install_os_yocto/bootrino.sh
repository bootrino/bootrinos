#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "Install Yocto Linux",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "Install Yocto Linux from Tiny Core Linux. WARNING THIS IS AN EXAMPLE ONLY - THERE IS NO PASSWORD ON root USER!",
  "options": "",
  "logoURL": "",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_yocto/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "https://github.com/bootrino/",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "yocto",
    "linux",
    "runfromram"
  ]
}
BOOTRINOJSONMARKER


determine_cloud_type()
{
    # case with wildcard pattern is how to do "endswith" in shell

    SIGNATURE=$(cat /sys/class/dmi/id/sys_vendor)
    case "${SIGNATURE}" in
         "DigitalOcean")
            CLOUD_TYPE="digitalocean"
            ;;
    esac

    SIGNATURE=$(cat /sys/class/dmi/id/product_name)
    case "${SIGNATURE}" in
         "Google Compute Engine")
            CLOUD_TYPE="googlecomputeengine"
            ;;
    esac

    SIGNATURE=$(cat /sys/class/dmi/id/product_version)
    case ${SIGNATURE} in
         *amazon)
            echo Detected cloud Amazon Web Services....
            CLOUD_TYPE="amazonwebservices"
            ;;
    esac
    echo Detected cloud ${CLOUD_TYPE}
}

setup()
{
    export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/bin
    OS=tinycore
    set +xe
    KERNEL_FILENAME="bzImage"
    INITRAMFS_FILENAME="core-image-minimal-qemux86-64.cpio.gz"
    BOOT_PARTITION=/mnt/boot_partition/
}

process_arguments()
{
    # ref https://stackoverflow.com/a/28466267
    REBOOT=true
    while getopts ab:c-: arg; do
      case $arg in
        r )  REBOOT="$OPTARG" ;;
        - )  LONG_OPTARG="${OPTARG#*=}"
             case $OPTARG in
               reboot=?* )  REBOOT="$LONG_OPTARG" ;;
               reboot*   )  REBOOT=false ;;
               '' )        break ;; # "--" terminates argument processing
               * )         echo "Illegal option --$OPTARG" >&2; exit 2 ;;
             esac ;;
        \? ) exit 2 ;;  # getopts already reported the illegal option
      esac
    done
    shift $((OPTIND-1)) # remove parsed options and args from $@ list
}

download_files()
{
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_yocto/
    cd /mnt/boot_partition
    sudo wget -O ${BOOT_PARTITION}${KERNEL_FILENAME} ${URL_BASE}${KERNEL_FILENAME}
    sudo wget -O ${BOOT_PARTITION}${INITRAMFS_FILENAME} ${URL_BASE}${INITRAMFS_FILENAME}
    sudo wget -O ${BOOT_PARTITION}rootfs_overlay_initramfs.gz ${URL_BASE}rootfs_overlay_initramfs.gz
}

determine_cloud_type()
{
    # case with wildcard pattern is how to do "endswith" in shell

    SIGNATURE=$(cat /sys/class/dmi/id/sys_vendor)
    case "${SIGNATURE}" in
         "DigitalOcean")
            CLOUD_TYPE="digitalocean"
            ;;
    esac

    SIGNATURE=$(cat /sys/class/dmi/id/product_name)
    case "${SIGNATURE}" in
         "Google Compute Engine")
            CLOUD_TYPE="googlecomputeengine"
            ;;
    esac

    SIGNATURE=$(cat /sys/class/dmi/id/product_version)
    case ${SIGNATURE} in
         *amazon)
            echo Detected cloud Amazon Web Services....
            CLOUD_TYPE="amazonwebservices"
            ;;
    esac
    echo Detected cloud ${CLOUD_TYPE}
}


netmask2cidr() 
{ 
        # Some shells cannot handle hex arithmetic, so we massage it slightly 
        # Buggy shells include FreeBSD sh, dash and busybox. 
        # bash and NetBSD sh don't need this. 
        case $1 in 
                0x*) 
                local hex=${1#0x*} quad= 
                while [ -n "${hex}" ]; do 
                        local lastbut2=${hex#??*} 
                        quad=${quad}${quad:+.}0x${hex%${lastbut2}*} 
                        hex=${lastbut2} 
                done 
                set -- ${quad} 
                ;; 
        esac 

        local i= len= 
        local IFS=. 
        for i in $1; do 
                while [ ${i} != "0" ]; do 
                        len=$((${len} + ${i} % 2)) 
                        i=$((${i} >> 1)) 
                done 
        done 

        echo "${len}" 
}

make_systemd_network_config_file()
{

    if [ "${CLOUD_TYPE}" == "amazonwebservices" ]; then
      echo Configure amazonwebservices....
        cd ${BOOT_PARTITION}
      # dhcp seems to work properly on AWS so no specific additional network setup needed
        sh -c 'cat > wired.network' << EOF
[Match]
Name=e*

[Network]
DHCP=ipv4

[DHCP]
UseMTU=true
EOF
    fi;

    if [ "${CLOUD_TYPE}" == "digitalocean" ]; then
        echo Configure digitalocean....
        # if on digitalocean
        ifconfig eth0 169.254.1.1 netmask 255.255.0.0
        route add -net 169.254.0.0 netmask 255.255.0.0 dev eth0
        PUBLIC_IPV4=$(wget -O - http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
        NETMASK=$(wget -O - http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/netmask)
        CIDR=$(netmask2cidr ${NETMASK})
        GATEWAY=$(wget -O - http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/gateway)
        ip addr add ${PUBLIC_IPV4}/${NETMASK} dev eth0
        echo NETMASK ${NETMASK}
        echo PUBLIC_IPV4 ${PUBLIC_IPV4}
        echo GATEWAY ${GATEWAY}
        ip route add default via ${GATEWAY}
        # configure name servers
        echo nameserver 67.207.67.3 > /etc/resolv.conf
        echo nameserver 67.207.67.2 >> /etc/resolv.conf
        cd ${BOOT_PARTITION}
        sh -c 'cat > wired.network' << EOF
[Match]
Name=e*

[Network]
Address=${PUBLIC_IPV4}/${CIDR}
Gateway=${GATEWAY}
DNS=67.207.67.3
DNS=67.207.67.2
EOF
    fi;

    if [ "${CLOUD_TYPE}" == "googlecomputeengine" ]; then
        echo Configure googlecomputeengine....
        cd ${BOOT_PARTITION}
        # Google needs mtu 1460
        sh -c 'cat > wired.network' << EOF
[Match]
Name=en*

[Network]
DHCP=ipv4

[DHCP]
UseMTU=true

EOF
    fi;
}

add_initrd_to_APPEND_in_syslinuxcfg()
{
sudo sed -i "/^[[:space:]]*APPEND/ {/ initrd+=${1}/! s/.*/& initrd+=${1}/}" ${BOOT_PARTITION}syslinux.cfg
}

make_syslinuxcfg()
{
cd ${BOOT_PARTITION}
sudo sh -c 'cat > syslinux.cfg' << EOF
SERIAL 0
DEFAULT operatingsystem
# on EC2 this ensures output to both VGA and serial consoles
# console=ttyS0 console=tty0
LABEL operatingsystem
    COM32 linux.c32 ${KERNEL_FILENAME} console=ttyS0  console=tty0
    APPEND initrd=${INITRAMFS_FILENAME} initrdfile=wired.network@/etc/systemd/network/wired.network
EOF

}

reboot_or_not()
{
    # --reboot is an optional argument to this script, but if provided, it must be true or false
    # if not provided then REBOOT=false (see above)
    # typically, if the goal is just to do a straight OS install then you'd reboot
    # but if this script is called by another script to do an OS install prior to other stuff, then you wouldn't reboot
    case $REBOOT in
        true )
            echo "OS installation complete. REBOOTING!" | sudo tee -a /dev/tty0
            echo "OS installation complete. REBOOTING!" | sudo tee -a /dev/console
            echo "OS installation complete. REBOOTING!" | sudo tee -a /dev/ttyS0
            sudo reboot
            ;;
        false )
            echo "REBOOT is required at this point to launch" | sudo tee -a /dev/tty0
            echo "REBOOT is required at this point to launch" | sudo tee -a /dev/console
            echo "REBOOT is required at this point to launch" | sudo tee -a /dev/ttyS0
            ;;
        * )
            echo "--reboot must be true or false"
            exit 2
            ;;
    esac
}

determine_cloud_type
setup
process_arguments
download_files
make_syslinuxcfg
#add_initrd_to_APPEND_in_syslinuxcfg "rootfs_overlay_initramfs.gz"
determine_cloud_type
make_systemd_network_config_file
reboot_or_not

