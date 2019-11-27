#!/bin/bash -eux

SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
source "${SCRIPT_DIR}/common.sh"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOCAL_DOCKER_VOLUME="${VOLUMES_DIR}/var/lib/docker"

docker network create \
    --opt "com.docker.network.bridge.name=${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --attachable \
    --gateway=10.123.0.1 \
    --subnet=10.123.0.0/24 \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" || true

docker run \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_ADMIN \
    --cap-add=SYS_RESOURCE \
    --cpus=$(nproc) \
    --detach \
    --device=/dev/kvm:r \
    --device=/dev/net/tun:r \
    --device=/dev/vhost-net:rm \
    --dns=8.8.8.8 \
    --env=container=docker \
    --hostname="${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --interactive \
    --mount type=bind,source="${LOCAL_DOCKER_VOLUME}",target=/var/lib/docker \
    --mount type=bind,source="${VOLUMES_DIR}",target=/volumes \
    --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
    --mount type=tmpfs,destination=/run \
    --mount type=tmpfs,destination=/tmp \
    --mount type=tmpfs,destination=/var/run \
    --name="${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --network="${BARE_METAL_PROXY_CONTAINER_NAME}" \
    --publish=127.0.0.1:2222:2222/tcp \
    --rm \
    --runtime=runc \
    --security-opt seccomp=unconfined \
    --stop-signal=RTMIN+3 \
    --sysctl net.ipv4.ip_forward=1 \
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
#       during testing. The real problem here is the || true at the end.  May need a exit code check of some kind.
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
    docker network create \
        --opt "com.docker.network.bridge.name=${VM_CONTAINER_NAME}" \
        --attachable \
        --gateway=10.123.1.1 \
        --subnet=10.123.1.0/24 \
        "${VM_CONTAINER_NAME}" || true

docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker run \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_ADMIN \
        --cap-add=SYS_RESOURCE \
        --cpus=$(nproc) \
        --detach \
        --device=/dev/kvm:r \
        --device=/dev/net/tun:rwm \
        --device=/dev/vhost-net:rwm \
        --dns=8.8.8.8 \
        --hostname="${VM_CONTAINER_NAME}" \
        --interactive \
        --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup,readonly \
        --mount type=bind,source=/volumes,target=/volumes \
        --mount type=tmpfs,destination=/run \
        --mount type=tmpfs,destination=/tmp \
        --name="${VM_CONTAINER_NAME}" \
        --network="${VM_CONTAINER_NAME}" \
        --publish=2222:22/tcp \
        --runtime=kata \
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
            /setup.sh \
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
        systemctl start sshd

sudo ip route del 10.123.1.0/24 || true
sudo ip route add 10.123.1.0/24 via 10.123.0.2

docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker exec \
        --interactive \
        --tty \
        "${VM_CONTAINER_NAME}" \
        docker network create \
            --opt="com.docker.network.bridge.name=${RUNC_IN_KATA_CONTAINER_NAME}" \
            --attachable \
            --gateway=10.123.2.1 \
            --subnet=10.123.2.0/24 \
            "${RUNC_IN_KATA_CONTAINER_NAME}" || true


docker exec \
    --interactive \
    --tty \
    "${BARE_METAL_PROXY_CONTAINER_NAME}" \
    docker exec \
        --interactive \
        --tty \
        "${VM_CONTAINER_NAME}" \
        docker run \
            --cpus=$(nproc) \
            --dns=8.8.8.8 \
            --hostname="${RUNC_IN_KATA_CONTAINER_NAME}" \
            --interactive \
            --name="${RUNC_IN_KATA_CONTAINER_NAME}" \
            --network="${RUNC_IN_KATA_CONTAINER_NAME}" \
            --rm \
            --runtime runc \
            --tty \
            debian:buster \
            bash
