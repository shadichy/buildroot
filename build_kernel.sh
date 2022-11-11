#!/bin/bash

if [ $EUID -ne 0 ]; then
    printf "ERROR: Please run this script as root!\n"
    exit 1
fi

WORKDIR=$(pwd)

[ -d ${WORKDIR}/tmp ] || mkdir -p ${WORKDIR}/tmp

mount -t overlay overlay -o lowerdir=${WORKDIR}/build,upperdir=${WORKDIR}/overlay,workdir=${WORKDIR}/tmp ${WORKDIR}/build

if  which arch-chroot &> /dev/null; then
    arch-chroot ${WORKDIR}/build mkinitcpio -P
else
    mount -t proc /proc ${WORKDIR}/build/proc/
    mount -t sysfs /sys ${WORKDIR}/build/sys/
    mount --rbind /dev ${WORKDIR}/build/dev/
    mount --rbind /run ${WORKDIR}/build/run/

    chroot ${WORKDIR}/build mkinitcpio -P

    sleep 2
fi

umount --recursive ${WORKDIR}/build

cp ${WORKDIR}/overlay/boot/vmlinuz-* ${WORKDIR}/overlay/boot/initramfs-*.img ${WORKDIR}/iso/boot/


grub-mkrescue -V "EXTOS" -o "ExtOS-beta.iso" --modules="fat exfat ext2 btrfs hfs ntfs part_msdos part_gpt part_apple" iso 
