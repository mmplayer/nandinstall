#!/bin/bash
#Author: cubieplayer(cubieplayer@github.com)
#Copyright (c) 2013, cubieplayer. All rights reserved.

set -e

PWD="`pwd`"
CWD=$(cd "$(dirname "$0")"; pwd)

NAND="/dev/nand"
NANDA="/dev/nanda"
NANDB="/dev/nandb"

BOOT="/mnt/nanda"
ROOTFS="/mnt/nandb"

CUBIAN_PART="${CWD}/cubian_nand.gz"
CURRENT_PART="${CWD}/nand.tmp"

BOOTLOADER="${CWD}/bootloader"

EXCLUDE="${CWD}/exclude.txt"

isRoot() {
  if [ "`id -u`" -ne "0" ]; then
    echo "this script needs to be run as root, try again with sudo"
    return 1
  fi
  return 0
}

promptyn () {
while true; do
  read -p "$1 " yn
  case $yn in
    [Yy]* ) return 0;;
    [Nn]* ) return 1;;
    * ) echo "Please answer yes or no.";;
  esac
done
}

umountNand() {
sync
sleep 5
for n in ${NAND}*;do
    if [ "${NAND}" != "$n" ];then
        if mount|grep ${n};then
            echo "umounting ${n}"
            umount -l $n
            sleep 2
        fi
    fi
done
}

formatNand(){
tar -xzOf $CUBIAN_PART | dd of=$NAND
}

nandPartitionOK(){
dd if=/dev/nand of=$CURRENT_PART bs=1M count=1>/dev/null 2>&1
md51=$(md5sum $CURRENT_PART | cut -c1-32)
md52=$(tar -xzOf $CUBIAN_PART | md5sum | cut -c1-32)
rm $CURRENT_PART
if [[ "$md51" = "$md52" ]]
then
return 0
else
return 1
fi
}

mkFS(){
mkfs.vfat $NANDA
mkfs.ext4 -O ^has_journal $NANDB
}

mountDevice(){
if [ ! -d $BOOT ];then
    mkdir $BOOT
fi
mount $NANDA $BOOT

if [ ! -d $ROOTFS ];then
    mkdir $ROOTFS
fi
mount $NANDB $ROOTFS
}

installBootloader(){
rm -rf $BOOT/*
rsync -avc $BOOTLOADER/* $BOOT
rsync -avc /boot/script.bin /boot/uEnv.txt /boot/uImage $ROOTFS/boot/
}

installRootfs(){
rsync -avc --exclude-from=$EXCLUDE / $ROOTFS
echo "please wait"
sync
}

patchRootfs(){
cat > ${ROOTFS}/etc/fstab <<END
#<file system>	<mount point>	<type>	<options>	<dump>	<pass>
$NANDB	/		ext4	defaults	0	1
END
}

isRoot
if nandPartitionOK;then
    umountNand
    echo "continue to install on NAND"   
    mkFS
    echo "mount NAND partitions"   
    mountDevice
    echo "install bootloader"
    installBootloader
    echo "install rootfs"
    installRootfs
    patchRootfs
    umountNand
    echo "success! remember to remove your SD card then reboot"
    if promptyn "shutdown now?";then
        shutdown -h now
    fi
else
    if promptyn "This will completely destory your data on $NAND, Are you sure to continue?"; then
        umountNand
        formatNand   
        echo ""
        echo "!!! Reboot is required for changes to take effect !!!"
        echo ""
        echo "Run this script again after the system is up"
        if promptyn "reboot now?";then
            shutdown -r now
        fi
    fi
fi
