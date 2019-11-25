#!/bin/bash -eux
dd if=/dev/zero of=volumes/var_lib_docker.img bs=1M count=10000
mkfs.btrfs volumes/var_lib_docker.img