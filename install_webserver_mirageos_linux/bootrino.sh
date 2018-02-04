#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "MirageOS web server for Linux",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "MirageOS web server for Linux",
  "options": "",
  "logoURL": "",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_webserver_mirageos_linux/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "https://github.com/bootrino/",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "linux",
    "runfromram",
    "tinycore",
    "mirageos"
  ]
}
BOOTRINOJSONMARKER

setup()
{
    export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/bin
    OS=tinycore
    set +xe
    PACKAGE_NAME="mirageos_webserver_linux"
}

install_tinycore_os()
{
    # download and run the bootrino that installs the tiny core OS
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_tinycore/
    mkdir -p /opt/install_tinycore_os
    cd /opt/install_tinycore_os
    sudo wget ${URL_BASE}bootrino.sh
    sudo chmod ug+rx bootrino.sh
    source ./bootrino.sh --reboot=false
}

download_files()
{
    # download the tinycore packages needed
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_webserver_mirageos_linux/
    mkdir -p /home/tc/${PACKAGE_NAME}_initramfs.src/opt/
    cd /home/tc/${PACKAGE_NAME}_initramfs.src/opt/
    sudo wget -O /home/tc/${PACKAGE_NAME}_initramfs.src/opt/conduit_server ${URL_BASE}conduit_server
    sudo chmod ug+rx *
}

download_tinycore_packages()
{
    # download the tinycore packages needed
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_webserver_mirageos_linux/
    mkdir -p /home/tc/${PACKAGE_NAME}_initramfs.src/opt/tce/optional
    cd /home/tc/${PACKAGE_NAME}_initramfs.src/opt/tce/optional
    # MirageOS needs libgmp.so.10 and its in gmp.tcz so install it
    sudo wget -O /home/tc/${PACKAGE_NAME}_initramfs.src/opt/tce/optional/gmp.tcz ${URL_BASE}gmp.tcz
    sudo chmod ug+rx *
}


make_start_script()
{
DIRECTORY=/home/tc/${PACKAGE_NAME}_initramfs.src/opt/bootlocal_enabled/
mkdir -p ${DIRECTORY}
cd ${DIRECTORY}
sudo sh -c 'cat > ${DIRECTORY}60_start_mirageos_webserver_linux' << EOF
#!/usr/bin/env sh
# don't crash out if there is an error
set +xe

start_application()
{
    echo "Starting mirageos_webserver_linux...."
    # Tiny Core has most of the libraries that we need for MirageOS except libgmp.so.10 which is in gmp.tcz
    sudo su - tc -c "tce-load -i /opt/tce/optional/gmp.tcz"
    # annoying but ld-linux-x86-64.so.2 is in /lib so we need to link /lib64 to /lib
    sudo ln -s /lib /lib64
    cd /opt
    sudo ./conduit_server &
}
start_application
EOF
chmod u=rwx,g=rx,o=rx 60_start_mirageos_webserver_linux
}

make_initramfs()
{
    BOOT_PARTITION=/mnt/boot_partition/
    cd /home/tc/${PACKAGE_NAME}_initramfs.src
    find . | cpio -H newc -o | gzip -9 > ${BOOT_PARTITION}${PACKAGE_NAME}_initramfs.gz
    # append the initramfs to the INITRD line in syslinux.cfg
    sudo sed -i "/^[[:space:]]*INITRD/ {/${PACKAGE_NAME}_initramfs.gz/! s/.*/&,${PACKAGE_NAME}_initramfs.gz/}" ${BOOT_PARTITION}syslinux.cfg
}

post_installation_cleanup() {
    # installation is complete. we need to make sure there's no chance the bootrino will run again.
    # remove bootrino initrams from syslinux.cfg  important! note that we must do it twice, first for comma prefix
    sudo sed -i "s/\,bootrino_initramfs.gz//g" ${BOOT_PARTITION}syslinux.cfg
    sudo sed -i "s/bootrino_initramfs.gz//g" ${BOOT_PARTITION}syslinux.cfg
    # remove the bootrino initramfs
    sudo rm -f ${BOOT_PARTITION}bootrino_initramfs.gz
}

setup
install_tinycore_os
download_files
download_tinycore_packages
make_start_script
make_initramfs
post_installation_cleanup
echo "rebooting into Tiny Core Linux now ..."
echo "rebooting into Tiny Core Linux now ..." > /dev/console
echo "rebooting into Tiny Core Linux now ..." > /dev/tty0
sudo reboot


