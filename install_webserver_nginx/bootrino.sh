#!/usr/bin/env sh
read BOOTRINOJSON <<"BOOTRINOJSONMARKER"
{
  "name": "Install nginx for Tiny Core",
  "version": "0.0.1",
  "versionDate": "2018-01-01T09:00:00Z",
  "description": "Installs nginx into Tiny Core",
  "options": "",
  "logoURL": "",
  "readmeURL": "https://raw.githubusercontent.com/bootrino/bootrinos/master/install_webserver_nginx/README.md",
  "launchTargetsURL": "https://raw.githubusercontent.com/bootrino/launchtargets/master/defaultLaunchTargetsLatest.json",
  "websiteURL": "https://github.com/bootrino/",
  "author": {
    "url": "https://www.github.com/bootrino",
    "email": "bootrino@gmail.com"
  },
  "tags": [
    "linux",
    "runfromram",
    "webserver",
    "tinycore",
    "nginx"
  ]
}
BOOTRINOJSONMARKER

setup()
{
    export PATH=$PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/bin
    OS=tinycore
    set +xe
    PACKAGE_NAME="nginx"
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

download_tinycore_packages()
{
    # download the tinycore packages needed
    URL_BASE=https://raw.githubusercontent.com/bootrino/bootrinos/master/install_webserver_nginx/
    mkdir -p /home/tc/${PACKAGE_NAME}_initramfs.src/opt/tce/optional
    cd /home/tc/${PACKAGE_NAME}_initramfs.src/opt/tce/optional
    sudo wget -O /home/tc/${PACKAGE_NAME}_initramfs.src/opt/tce/optional/nginx.tcz ${URL_BASE}nginx.tcz
    sudo chmod ug+rx *
}

make_start_script()
{
DIRECTORY=/home/tc/${PACKAGE_NAME}_initramfs.src/opt/bootlocal_enabled/
mkdir -p ${DIRECTORY}
cd ${DIRECTORY}
sudo sh -c 'cat > ${DIRECTORY}60_start_nginx' << EOF
#!/usr/bin/env sh
# don't crash out if there is an error
set +xe
# install the tinycore packages
# tinycore requires not runnning tce-load as root so we run it as tiny core default user tc
sudo su - tc -c "tce-load -i /opt/tce/optional/nginx.tcz"

start_application()
{
    echo "Starting nginx...."
    sudo /usr/local/etc/init.d/nginx start
}
start_application
EOF
chmod u=rwx,g=rx,o=rx 60_start_nginx
}

make_index_html()
{
DIRECTORY=/home/tc/${PACKAGE_NAME}_initramfs.src/usr/local/nginx/html/
mkdir -p ${DIRECTORY} 
cd ${DIRECTORY}
# make an index.html to serve
sudo sh -c 'cat > ${DIRECTORY}index.html' << EOF
hello world<br/>
EOF
chmod u=rwx,g=rx,o=rx index.html
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
download_tinycore_packages
make_start_script
make_index_html
make_initramfs
post_installation_cleanup
echo "rebooting into Tiny Core Linux now ..."
echo "rebooting into Tiny Core Linux now ..." > /dev/console
echo "rebooting into Tiny Core Linux now ..." > /dev/tty0
sudo reboot


