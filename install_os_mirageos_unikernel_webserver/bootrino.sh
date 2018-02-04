#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "MirageOS web server Unikernel on Solo5",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "MirageOS web server Unikernel on Solo5",
  "options": "",
  "logoURL": "",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_mirageos_unikernel_webserver/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "https://github.com/bootrino/",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "unikernel",
    "solo5",
    "runfromram",
    "mirageos"
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
    KERNEL_FILENAME="conduit_server.virtio"
    #KERNEL_FILENAME="unikernel_lucina.bin"
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
    # download the tinycore packages needed
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_mirageos_unikernel_webserver/
    cd /mnt/boot_partition
    sudo wget -O /mnt/boot_partition/${KERNEL_FILENAME} ${URL_BASE}${KERNEL_FILENAME}
    sudo chmod ug+rx *
}

overwrite_syslinuxcfg()
{
sudo sh -c 'cat > /mnt/boot_partition/syslinux.cfg' << EOF
SERIAL 0
DEFAULT operatingsystem
LABEL operatingsystem
    KERNEL mboot.c32
    APPEND ${KERNEL_FILENAME}
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
download_files
overwrite_syslinuxcfg
reboot_or_not

