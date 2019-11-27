#!/bin/bash -eu

SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOCAL_DOCKER_VOLUME="${VOLUMES_DIR}/var/lib/docker"

mkdir -p "${LOCAL_DOCKER_VOLUME}"

docker build . \
    --tag nested-kata-build-assistant \
    --target nested-kata-build-assistant

docker run \
    --dns=8.8.8.8 \
    --mount type=bind,source="${SCRIPT_DIR}",target=/project \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    --name=nested-kata-build-assistant \
    --rm \
    --runtime=runc \
    nested-kata-build-assistant \
    /project/assets/initial_setup.sh

