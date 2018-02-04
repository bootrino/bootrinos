#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "Install Tiny Core 64",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "Installs Tiny Core 64.",
  "options": "",
  "logoURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/tinycore_minimal-8.2.1_x86-64/tiny-core-linux-7-logo.png",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_tinycore/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "linux",
    "runfromram",
    "tinycore",
    "python"
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
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/tinycore_minimal-8.2.1_x86-64/

    # load the bootrino environment variables: CLOUD_TYPE BOOTRINO_URL BOOTRINO_PROTOCOL BOOTRINO_SHA256
    # allexport ensures exported variables come into current environment
    set -o allexport
    [ -f /bootrino/envvars.sh ] && . /bootrino/envvars.sh
    set +o allexport

    # base directory for running this script
    sudo mkdir -p /opt
    cd /opt

    echo "------->>> cloud type: ${CLOUD_TYPE}"

    # Sometimes different operating systems name the hard disk devices differently even on the same cloud.
    # So we need to define the name for the current OS, plus the root_partition OS
    # This ise useful when for example running a script on Ubuntu that is preparing to boot Tiny Core, where
    # the hard disk devices names are different

    if [ "${CLOUD_TYPE}" == "googlecomputeengine" ]; then
      DISK_DEVICE_NAME_TARGET_OS="sda"
      DISK_DEVICE_NAME_CURRENT_OS="sda"
    fi;

    if [ "${CLOUD_TYPE}" == "amazonwebservices" ]; then
      DISK_DEVICE_NAME_TARGET_OS="xvda"
      DISK_DEVICE_NAME_CURRENT_OS="xvda"
    fi;

    if [ "${CLOUD_TYPE}" == "digitalocean" ]; then
      DISK_DEVICE_NAME_TARGET_OS="vda"
      DISK_DEVICE_NAME_CURRENT_OS="vda"
    fi;

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

create_syslinuxcfg()
{
# notice that we did not include bootrino_initramfs.gz on the initrd. This ensures the
# bootrino does run again on next boot, which would be a problem because if it did,
# then the install process would run over and over.
# if you did want bootrino to run, then the initrd should look like this:
#   INITRD corepure64.gz,rootfs_overlay_initramfs.gz,bootrino_initramfs.gz

echo "------->>> create syslinux.cfg"
sudo sh -c 'cat > /mnt/boot_partition/syslinux.cfg' << EOF
SERIAL 0
DEFAULT operatingsystem
# on EC2 this ensures output to both VGA and serial consoles
# console=ttyS0 console=tty0
LABEL operatingsystem
    KERNEL vmlinuz64 tce=/opt/tce noswap modules=ext4 console=tty0 console=ttyS0
    INITRD corepure64.gz,rootfs_overlay_initramfs.gz
EOF
}

install_tinycore()
{
    # download the operating system files for tinycore
    cd /mnt/boot_partition
    sudo wget -O /mnt/boot_partition/vmlinuz64 ${URL_BASE}vmlinuz64
    sudo wget -O /mnt/boot_partition/corepure64.gz ${URL_BASE}corepure64.gz
    sudo wget -O /mnt/boot_partition/rootfs_overlay_initramfs.gz ${URL_BASE}rootfs_overlay_initramfs.gz
}

set_password()
{
    # if bootrino user has not defined a password environment variable when launching then make a random one
    NEWPW=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10`
    if ! [[ -z "${PASSWORD}" ]]; then
      NEWPW=${PASSWORD}
    fi
    sudo sh -c 'chpasswd' << EOF
tc:${NEWPW}
EOF
    echo "Password for tc user is ${NEWPW}"
    echo "Password for tc user is ${NEWPW}" > /dev/console
    echo "Password for tc user is ${NEWPW}" > /dev/tty0
    echo "Password can also be found in /opt/tcuserpassword.txt"
    sudo sh -c 'cat > /opt/tcuserpassword.txt' << EOF
${NEWPW}
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
#set_password
create_syslinuxcfg
install_tinycore
reboot_or_not

