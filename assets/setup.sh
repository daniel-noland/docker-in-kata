#!/bin/bash -eux
[[ ! -b /dev/loop0 ]] && mknod /dev/loop0 b 7 0
losetup /dev/loop0 /volumes/var_lib_docker.img
mkdir -p /var/lib/docker
mount -o compress=zstd /dev/loop0 /var/lib/docker
systemctl start docker