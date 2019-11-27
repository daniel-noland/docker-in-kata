FROM debian:buster as nested-kata-build-assistant

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    apt-transport-https \
    bc \
    bison \
    bridge-utils \
    btrfs-progs \
    build-essential \
    ca-certificates \
    cpio \
    curl \
    flex \
    gnupg2 \
    kmod \
    libelf-dev \
    libncurses5-dev \
    libssl-dev \
    lzop \
    openssh-client \
    openssh-server \
    software-properties-common \
    systemd \
    xz-utils

COPY ./assets/etc/apt/sources.list /etc/apt/sources.list

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

FROM nested-kata-build-assistant as kata

ENV ARCH=x86_64
ENV KATA_BRANCH=master
ENV VERSION_ID=10
RUN echo "deb http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/${KATA_BRANCH}/Debian_${VERSION_ID}/ /" \
  > /etc/apt/sources.list.d/kata-containers.list
RUN curl -sL http://download.opensuse.org/repositories/home:/katacontainers:/releases:/${ARCH}:/${KATA_BRANCH}/Debian_${VERSION_ID}/Release.key \
  | apt-key add -

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
    kata-proxy \
    kata-runtime \
    kata-shim

RUN systemctl enable ssh
RUN systemctl enable docker

RUN systemctl mask systemd-firstboot
RUN systemctl mask getty.slice
RUN systemctl mask getty.target

RUN mkdir -p /etc/docker
RUN echo '{ "runtimes": { "kata": { "path": "/usr/bin/kata-runtime" } } }' > /etc/docker/daemon.json

RUN apt-get install --yes --no-install-recommends golang git wget
RUN go get -d -u github.com/kata-containers/packaging || true
WORKDIR /root/go/src/github.com/kata-containers/packaging/kernel
RUN wget -q "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.tar.xz" \
 && tar xf linux-5.4.tar.xz
COPY ./assets/kernel.config linux-5.4/.config

RUN ./build-kernel.sh -c linux-5.4/.config -k linux-5.4/ setup \
 && ./build-kernel.sh -c linux-5.4/.config -k linux-5.4/ build \
 && ./build-kernel.sh -c linux-5.4/.config -k linux-5.4/ install

COPY --chown=root:root ./assets/root/.ssh/ /root/.ssh/
COPY --chown=root:root ./assets/setup.sh /setup.sh

CMD ["/lib/systemd/systemd"]
