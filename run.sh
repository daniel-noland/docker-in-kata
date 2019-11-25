#!/bin/bash -eux

# CONFIG: adjust desired container names and configs here
BARE_METAL_PROXY_CONTAINER_NAME="kata-in-docker"
VM_CONTAINER_NAME="kata"
RUNC_IN_KATA_CONTAINER_NAME="docker-in-kata"

# DEDUCED CONFIG: don't mess with these parameters unless you know what you are doing
SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOCAL_DOCKER_VOLUME="${VOLUMES_DIR}/var/lib/docker"

# Runtime logic
# TODO: automate inclusion of nested systemd container somehow (consider using docker export)
# TODO: pass in block device or directory to persist built docker artifacts
docker build "${SCRIPT_DIR}" \
    --tag "${BARE_METAL_PROXY_CONTAINER_NAME}"

# TODO: try to reduce the total caps given to this container
# TODO: look into using the --rm flag here (I guess it can work with --detach now)
# TODO: look into removing the seccomp=unconfined here.  Not sure it is helping anything
# TODO: change the --tmpfs flags to use --mount instead
docker run \
    --cap-add=IPC_LOCK \
    --cap-add=IPC_OWNER \
    --cap-add=NET_ADMIN \
    --cap-add=NET_BROADCAST \
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
    --mount type=bind,source="${SCRIPT_DIR}",target=/project \
    --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
    --mount type=bind,source=/var/lib/libvirt,target=/var/lib/libvirt \
    --mount type=tmpfs,destination=/run \
    --mount type=tmpfs,destination=/tmp \
    --mount type=tmpfs,destination=/var/run \
    --name "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --runtime runc \
    --security-opt seccomp=unconfined \
    --stop-signal=RTMIN+3 \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}"

# TODO: make this smart enough to not require a sleep.  Maybe do until a port goes up
sleep 1

# TODO: remove this cleanup logic when you are not testing or hide it behind a flag.  It is a huge overreach to just
#       blow away a container like this without any kind of warning or active consent from the user.
# NOTE: This is just a cleanup command (albeit an inelegant one).  We may have leftover container we don't care about
#       during testing. The real problem here is the || true at the end.  May need a
docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker container rm \
        --force \
        "${VM_CONTAINER_NAME}" \
    || true

# TODO: try to reduce the total caps given to this container
# TODO: look into using --cgroup-parent here instead of mounting /sys/fs/cgroup
# TODO: look into using --sysctl to explicitly enable net.ipv4.ip_forward=1 instead of using exec hacks
docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker run \
        --cap-add=IPC_LOCK \
        --cap-add=IPC_OWNER \
        --cap-add=NET_ADMIN \
        --cap-add=NET_BROADCAST \
        --cap-add=SYS_ADMIN \
        --cap-add=SYS_RESOURCE \
        --detach \
        --hostname "${VM_CONTAINER_NAME}" \
        --interactive \
        --mount type=bind,source=/project,target=/project \
        --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
        --mount type=tmpfs,destination=/run \
        --mount type=tmpfs,destination=/tmp \
        --name "${VM_CONTAINER_NAME}" \
        --runtime kata \
        --sysctl net.ipv4.ip_forward=1 \
        --tty \
        libvirtd

# TODO: make this smart enough to not require a sleep.  Maybe do until a port goes up
sleep 1

docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker exec \
        --interactive \
        --tty \
        "${VM_CONTAINER_NAME}" \
        systemctl start docker

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
            --runtime runc \
            --tty \
            debian:buster \
            bash
