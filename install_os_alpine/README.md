This installs Alpine Linux

WARNING THIS IS AN EXAMPLE ONLY - THERE IS NO PASSWORD ON root USER!

# after Alpine is booted, if you want swap space:
mkdir -p /mnt/root_partition
mount /dev/vda1 /mnt/root_partition/
fallocate -l 2G /mnt/root_partition/swapfile
chmod 600 /mnt/root_partition/swapfile
mkswap /mnt/root_partition/swapfile
swapon /mnt/root_partition/swapfile

# after Alpine is booted, if you want additional repos:
echo http://dl-3.alpinelinux.org/alpine/v3.7/community >> /etc/apk/repositories
apk update

# to install rust
echo http://dl-3.alpinelinux.org/alpine/v3.7/community >> /etc/apk/repositories
apk update
apk add rust
apk add cargo
# rustup?
https://github.com/fede1024/kafka-view/blob/ff4453b2230a41002e770cd5862dff8cf802acc6/Dockerfile


# to remount boot partition as read/write
mount -o remount,rw /dev/{DEVICE_NAME} /media/{DEVICE_NAME}
e.g. on Digital Ocean:
mount -o remount,rw /dev/vda13 /media/vda13

# to install python & pip
apk add --update python3 python3-dev py-pip