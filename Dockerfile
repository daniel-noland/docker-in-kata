FROM debian:buster as libvirtd

VOLUME ["/var/lib/libvirt"]

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    bridge-utils \
    dmidecode \
    dnsmasq \
    iproute2 \
    libvirt-daemon-system \
    libvirt-dev \
    libxml2-dev \
    libxslt-dev \
    netcat-openbsd \
    openssh-client \
    openssh-server \
    ovmf \
    qemu-system \
    qemu-utils \
    ruby-dev \
    systemd \
    systemd-container \
    vagrant \
    zlib1g-dev

RUN systemctl enable libvirtd
RUN systemctl enable ssh

RUN mkdir -p /var/lib/libvirt/images

RUN echo root:stateless | chpasswd
RUN systemctl mask systemd-firstboot
RUN systemctl mask getty.slice
RUN systemctl mask getty.target

COPY --chown=root:root ./assets/ /

RUN apt-get update \
 && apt-get build-dep --yes --no-install-recommends \
    ruby-libvirt \
    vagrant \
 && vagrant plugin install vagrant-libvirt

VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]

FROM libvirtd as kata-containers

ENV ARCH=x86_64
ENV KATA_BRANCH=master
ENV VERSION_ID=10
RUN echo "deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/${KATA_BRANCH}/Debian_${VERSION_ID}/ /" \
  > /etc/apt/sources.list.d/kata-containers.list
RUN curl -sL  http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/${KATA_BRANCH}/Debian_${VERSION_ID}/Release.key \
  | apt-key add -
RUN apt-get update \
 && apt-get --yes install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    kata-proxy \
    kata-runtime \
    kata-shim \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable"

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    containerd.io \
    docker-ce \
    docker-ce-cli

RUN systemctl enable docker

RUN mkdir -p /etc/docker
RUN echo '{ "runtimes": { "kata": { "path": "/usr/bin/kata-runtime" } } }' > /etc/docker/daemon.json

RUN apt-get install --yes --no-install-recommends golang git wget
RUN go get -d -u github.com/kata-containers/packaging || true
WORKDIR /root/go/src/github.com/kata-containers/packaging/kernel
RUN wget "https://git.kernel.org/torvalds/t/linux-5.4-rc8.tar.gz" \
 && tar xf linux-5.4-rc8.tar.gz
COPY ./assets/kernel.config linux-5.4-rc8/.config
RUN apt-get install --yes --no-install-recommends build-essential linux-source bc kmod cpio flex cpio libncurses5-dev bison libelf-dev libssl-dev
RUN ./build-kernel.sh -c linux-5.4-rc8/.config -k linux-5.4-rc8/ setup \
 && ./build-kernel.sh -c linux-5.4-rc8/.config -k linux-5.4-rc8/ build \
 && ./build-kernel.sh -c linux-5.4-rc8/.config -k linux-5.4-rc8/ install
