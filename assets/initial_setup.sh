#!/bin/bash -eux

BARE_METAL_PROXY_CONTAINER_NAME="kata-in-docker"
VM_CONTAINER_NAME="kata"
RUNC_IN_KATA_CONTAINER_NAME="docker-in-kata"

SCRIPT_DIR="$(dirname $(readlink -f ${0}))/.."
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOCAL_DOCKER_VOLUME="${VOLUMES_DIR}/var/lib/docker"

mkdir -p "${VOLUMES_DIR}/var/lib/docker"

docker build "${SCRIPT_DIR}" \
    --tag "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --target kata

docker save "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    | lzop \
    > "${VOLUMES_DIR}/kata-in-docker.tar.lzo"

SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
dd if=/dev/zero of="${VOLUMES_DIR}/var_lib_docker.img" bs=1M count=10000
mkfs.btrfs "${VOLUMES_DIR}/var_lib_docker.img"
