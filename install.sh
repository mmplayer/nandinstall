#!/bin/bash
#Author: cubieplayer(cubieplayer@github.com)
#Copyright (c) 2013, cubieplayer. All rights reserved.

set -e

PWD="`pwd`"
CWD=$(cd "$(dirname "$0")"; pwd)

NAND="/dev/nand"
NANDA="/dev/nand1"
NANDB="/dev/nand3"

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
gzip -cd $CUBIAN_PART | dd of=$NAND
echo -e 'ANDROID!\0\0\0\0\0\0\0\0\c' > /dev/nand2
}

nandPartitionOK(){
dd if=/dev/nand of=$CURRENT_PART bs=1M count=1
zdiff $CUBIAN_PART $CURRENT_PART
partitionIdentical=$?
rm $CURRENT_PART
return $partitionIdentical
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
cd $BOOT
rm -rf *
rsync -avc $BOOTLOADER/* $BOOT
cp /boot/script.bin $ROOTFS/boot/
cp /boot/uEnv.txt $ROOTFS/boot/
cd $PWD
}

installRootfs(){
rsync -avc --exclude-from=$EXCLUDE / $ROOTFS
cp /boot/uImage $ROOTFS/boot/
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
