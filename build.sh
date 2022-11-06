#!/bin/bash

if [ $EUID -ne 0 ]; then
    printf "ERROR: Please run this script as root!\n"
    exit 1
fi

WORKDIR=$(pwd)

SFS_FLAGS="-comp zstd -Xcompression-level 22 -b 1M -no-duplicates -no-recovery -always-use-fragments"

ROOTFS_EXTRA=( "/usr/share/doc" "/usr/share/gtk-doc" "/usr/share/man" "/usr/share/info" )

ROOTFS_DEVEL=( "/usr/include" )

ROOTFS_EXCLUDE_LIST=( "/var" "/root" "/home" ${ROOTFS_EXTRA[@]} ${ROOTFS_DEVEL[@]} "/etc/makepkg.conf" "/etc/pacman.conf" "/usr/bin/makepkg" "/usr/bin/makepkg-template" )

root=$(ls -Ad ${WORKDIR}/build/*)

ROOTFS_EXCL=""
for e in ${ROOTFS_EXCLUDE_LIST[@]}; do
    d="${WORKDIR}/build${e}"
    if [[ $root == *"$d"* ]]; then
        for el in $(ls -A $d); do
            ROOTFS_EXCL+=" -e $(ls -Ad $d/$el)"
        done
        continue
    fi
    ROOTFS_EXCL+=" -e $d"
done

rm -rf ${WORKDIR}/out/*

mksquashfs ${WORKDIR}/build/ ${WORKDIR}/out/rootfs.sfs ${SFS_FLAGS} ${ROOTFS_EXCL}

for e in ${ROOTFS_DEVEL[@]}; do
    mkdir -p "${WORKDIR}/overlay${e}"
    rsync -a "${WORKDIR}/build${e}/" "${WORKDIR}/overlay${e}"
done
mksquashfs ${WORKDIR}/overlay/ ${WORKDIR}/out/rootfs-devel.sfs ${SFS_FLAGS} -e ${WORKDIR}/overlay/.empty
rm -rf ${WORKDIR}/overlay/*

for e in ${ROOTFS_EXTRA[@]}; do
    mkdir -p "${WORKDIR}/overlay${e}"
    rsync -a "${WORKDIR}/build${e}/" "${WORKDIR}/overlay${e}"
done
mksquashfs ${WORKDIR}/overlay/ ${WORKDIR}/out/rootfs-extra.sfs ${SFS_FLAGS} -e ${WORKDIR}/overlay/.empty
rm -rf ${WORKDIR}/overlay/*
