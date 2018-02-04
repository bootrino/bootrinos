#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "Install Alpine Linux",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "Install Alpine Linux from Tiny Core Linux. WARNING THIS IS AN EXAMPLE ONLY - THERE IS NO PASSWORD ON root USER!",
  "options": "",
  "logoURL": "",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_alpine/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "https://github.com/bootrino/",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "linux",
    "alpine",
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
    BOOT_PARTITION=/mnt/boot_partition/
    ROOT_PARTITION=/mnt/root_partition/
    ALPINE_ISO_NAME=alpine-vanilla-3.7.0-x86_64.iso
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

download_alpine()
{
    ALPINE_ISO_URL=http://dl-cdn.alpinelinux.org/alpine/v3.7/releases/x86_64/
    cd ${ROOT_PARTITION}
    sudo wget ${ALPINE_ISO_URL}${ALPINE_ISO_NAME}
}

download_alpine_packages()
{
    # if you want packages to be available on boot, put them in the cache dir on the boot_partition
    # https://wiki.alpinelinux.org/wiki/Local_APK_cache
    # note that these files cannot be stored on a ram disk
    # The cache is enabled by creating a symlink named /etc/apk/cache that points to the cache directory
    # setup-apkcache
    URL_BASE=http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64/
    sudo mkdir -p ${BOOT_PARTITION}cache
    cd ${BOOT_PARTITION}boot/apks/x86_64
    sudo wget ${URL_BASE}dhclient-4.3.5-r0.apk
    # dhclient depends libgcc
    sudo wget ${URL_BASE}libgcc-6.4.0-r5.apk
    # dhclient's scripts need bash
    sudo wget ${URL_BASE}bash-4.4.12-r2.apk
    # bash depends:
    sudo wget ${URL_BASE}pkgconf-1.3.10-r0.apk
    # bash depends:
    sudo wget ${URL_BASE}ncurses-terminfo-base-6.0_p20170930-r0.apk
    # bash depends:
    sudo wget ${URL_BASE}ncurses-terminfo-6.0_p20170930-r0.apk
    # bash depends:
    sudo wget ${URL_BASE}ncurses5-libs-5.9-r1.apk
    # bash depends:
    sudo wget ${URL_BASE}readline-7.0.003-r0.apk

    sudo chmod ug+rx *
}

download_apk_ovl()
{
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_alpine/
    cd ${BOOT_PARTITION}
    # goes in the root of the boot volume, where Alpine picks it ip
    sudo wget ${URL_BASE}localhost.apkovl.tar.gz
    sudo chmod ug+rx *
}

copy_alpine_from_iso_to_boot()
{
    sudo mkdir -p ${ROOT_PARTITION}alpinefiles
    sudo mount -o loop ${ROOT_PARTITION}${ALPINE_ISO_NAME} ${ROOT_PARTITION}alpinefiles
    sudo cp -r ${ROOT_PARTITION}alpinefiles/* ${BOOT_PARTITION}.
    sudo umount ${ROOT_PARTITION}alpinefiles
    sudo rm -rf ${ROOT_PARTITION}alpinefiles
}

reboot_or_not()
{
    # --reboot is an optional argument to this script, but if provided, it must be true or false
    # if not provided then REBOOT=true (see above)
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
download_alpine
copy_alpine_from_iso_to_boot
#the alpine packages are in the apkovl in /etc/apk/cache
#download_alpine_packages
download_apk_ovl
reboot_or_not

