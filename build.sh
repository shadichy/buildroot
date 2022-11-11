#!/bin/bash

if [ $EUID -ne 0 ]; then
    printf "ERROR: Please run this script as root!\n"
    exit 1
fi

. .env

WORKDIR=$(pwd)

SFS_FLAGS="-comp zstd -Xcompression-level 22 -b 1M -no-duplicates -no-recovery -always-use-fragments"

ROOTFS_EXTRA=( "/usr/share/doc" "/usr/share/gtk-doc" "/usr/share/man" "/usr/share/info" )

ROOTFS_DEVEL=( "/usr/include" )

ROOTFS_EXCLUDE_LIST+=( "/var" "/root" "/home" "/boot" "/cdrom" "/packages" "/.empty" "/etc/mtab" ${ROOTFS_EXTRA[@]} ${ROOTFS_DEVEL[@]} )

root=$(ls -Ad ${WORKDIR}/build/*)

ROOTFS_EXCL=""
for e in ${ROOTFS_EXCLUDE_LIST[@]}; do
    d="${WORKDIR}/build${e}"
    if [[ $root == *"$d"* ]] && [ "$d" != "/var" ]; then
        for el in $(ls -A $d); do
            ROOTFS_EXCL+=" -e $(ls -Ad $d/$el)"
        done
        continue
    fi
    ROOTFS_EXCL+=" -e $d"
done

mount | grep "${WORKDIR}/build/" &>/dev/null && umount ${WORKDIR}/build/* && umount ${WORKDIR}/build
mount | grep "${WORKDIR}/mount/" &>/dev/null && umount ${WORKDIR}/mount/*

rm -rf ${WORKDIR}/iso/rootfs.sfs
rm -rf ${WORKDIR}/iso/pkgs/rootfs*.sfs

mksquashfs ${WORKDIR}/build/ ${WORKDIR}/iso/rootfs.sfs ${SFS_FLAGS} ${ROOTFS_EXCL}
[ ! -d ${WORKDIR}/mount/default-profile ] && mkdir ${WORKDIR}/mount/default-profile
mount -o loop,ro ${WORKDIR}/blank-profile.data.img ${WORKDIR}/mount/default-profile
mksquashfs ${WORKDIR}/mount/default-profile/ ${WORKDIR}/iso/rootfs.sfs ${SFS_FLAGS}

for e in ${ROOTFS_DEVEL[@]}; do
    mkdir -p "${WORKDIR}/overlay${e}"
    rsync -a "${WORKDIR}/build${e}/" "${WORKDIR}/overlay${e}"
done
mksquashfs ${WORKDIR}/overlay/ ${WORKDIR}/iso/pkgs/rootfs-devel.sfs ${SFS_FLAGS} -e ${WORKDIR}/overlay/.empty
rm -rf ${WORKDIR}/overlay/*

for e in ${ROOTFS_EXTRA[@]}; do
    mkdir -p "${WORKDIR}/overlay${e}"
    rsync -a "${WORKDIR}/build${e}/" "${WORKDIR}/overlay${e}"
done
mksquashfs ${WORKDIR}/overlay/ ${WORKDIR}/iso/pkgs/rootfs-extra.sfs ${SFS_FLAGS} -e ${WORKDIR}/overlay/.empty
rm -rf ${WORKDIR}/overlay/*
