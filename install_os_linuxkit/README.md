This installs LinuxKit

THIS IS AN EXAMPLE ONLY!

To build LinuxKit on Ubuntu, start a clean Ubuntu virtual machine, then:

cd /opt
sudo apt update
sudo apt install build-essential
sudo apt install docker.io
git clone https://github.com/linuxkit/linuxkit.git
cd linuxkit/
make
export PATH=$PATH:/opt/linuxkit/bin
linuxkit build -format kernel+initrd linuxkit.yml

# LinuxKit has finished building.  
# We'll run a web server so we can copy off the built LinuxKit files.
busybox httpd -f

# from some other machine, download the output from the LinuxKit build process and put it on a web server 
curl -O (ip address)/linuxkit-initrd.img
curl -O (ip address)/linuxkit-kernel
curl -O (ip address)/linuxkit-cmdline
# also put a bootrino.sh into the web server directory
curl -O https://raw.githubusercontent.com/bootrino/bootrinos/master/install_os_linuxkit/

# now go to bootrino and launch an instance!



