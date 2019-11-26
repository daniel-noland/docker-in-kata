#!/bin/bash -eux

SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
source "${SCRIPT_DIR}/common.sh"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOCAL_DOCKER_VOLUME="${VOLUMES_DIR}/var/lib/docker"

docker run \
    --cap-add=ALL \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_ADMIN \
    --cap-add=SYS_RESOURCE \
    --detach \
    --device /dev/kvm:r \
    --device /dev/net/tun:r \
    --device /dev/vhost-net:rm \
    --env container=docker \
    --hostname "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --interactive \
    --mount type=bind,source="${LOCAL_DOCKER_VOLUME}",target=/var/lib/docker \
    --mount type=bind,source="${VOLUMES_DIR}",target=/volumes \
    --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
    --mount type=bind,source=/var/lib/libvirt,target=/var/lib/libvirt \
    --mount type=tmpfs,destination=/run \
    --mount type=tmpfs,destination=/tmp \
    --mount type=tmpfs,destination=/var/run \
    --name "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --rm \
    --runtime runc \
    --security-opt seccomp=unconfined \
    --stop-signal=RTMIN+3 \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}"

while true ; do
    docker exec \
        --interactive \
        --tty \
        "${BARE_METAL_PROXY_CONTAINER_NAME}" \
        /bin/sh -c "docker load < /volumes/kata-in-docker.tar" && break
    sleep 0.2
done


# NOTE: This is just a cleanup command (albeit an inelegant one).  We may have leftover container we don't care about
#       during testing. The real problem here is the || true at the end.  May need a
# TODO: remove this cleanup logic when you are not testing or hide it behind a flag.  It is a huge overreach to just
#       blow away a container like this without any kind of warning or active consent from the user.
docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker container rm \
        --force \
        "${VM_CONTAINER_NAME}" \
    || true

docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker run \
        --cap-add=ALL \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_ADMIN \
        --cap-add=SYS_RESOURCE \
        --detach \
        --device /dev/kvm:r \
        --device /dev/net/tun:rwm \
        --device /dev/vhost-net:rwm \
        --hostname "${VM_CONTAINER_NAME}" \
        --interactive \
        --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
        --mount type=bind,source=/volumes,target=/volumes \
        --mount type=tmpfs,destination=/run \
        --mount type=tmpfs,destination=/tmp \
        --name "${VM_CONTAINER_NAME}" \
        --runtime kata \
        --security-opt seccomp=unconfined \
        --sysctl net.ipv4.ip_forward=1 \
        --tty \
        kata-in-docker

while true; do
    docker exec \
        --interactive \
        --tty \
        "${BARE_METAL_PROXY_CONTAINER_NAME}" \
        docker exec \
            --interactive \
            --tty \
            "${VM_CONTAINER_NAME}" \
            /volumes/setup.sh \
    && break
    sleep 0.2
done

docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker exec \
        --interactive \
        --tty \
        "${VM_CONTAINER_NAME}" \
        docker run \
            --hostname "${RUNC_IN_KATA_CONTAINER_NAME}" \
            --interactive \
            --name "${RUNC_IN_KATA_CONTAINER_NAME}" \
            --rm \
            --runtime kata \
            --tty \
            debian:buster \
            bash
