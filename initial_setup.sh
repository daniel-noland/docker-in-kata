#!/bin/bash -eux

# DEDUCED CONFIG: don't mess with these parameters unless you know what you are doing
SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
source "${SCRIPT_DIR}/common.sh"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOCAL_DOCKER_VOLUME="${VOLUMES_DIR}/var/lib/docker"

docker build "${SCRIPT_DIR}" \
    --tag "${BARE_METAL_PROXY_CONTAINER_NAME}"

docker save "${BARE_METAL_PROXY_CONTAINER_NAME}" > "${SCRIPT_DIR}/volumes/kata-in-docker.tar"

SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
dd if=/dev/zero of="${SCRIPT_DIR}/volumes/var_lib_docker.img" bs=1M count=10000
mkfs.btrfs "${SCRIPT_DIR}/volumes/var_lib_docker.img"