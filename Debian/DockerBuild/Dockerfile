ARG BASE_IMAGE=debian:bookworm

FROM ${BASE_IMAGE}

# Need to defined this after the from as well so it can be used in this step
ARG BASE_IMAGE

LABEL maintainer="Jason Townsend"

# Args
ARG BUILD_DATE
ARG REVISION
ARG BUILD_VERSION
ARG DEBIAN_FRONTEND=noninteractive
ARG DOCKER_CLI_EXPERIMENTAL="enabled"
ARG BUILDX_VERSION="0.18.0"

#Environment Variables
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV TZ=Europe/London
ENV DOCKER_BUILDKIT=1

ENV NODE_VERSION=18.16.1 \
    NVM_DIR=/root/.nvm \
    NVM_VERSION=0.39.2 \
    NVM_SHA256=c1e672cd63737cd3e166ad43dffcb630a3bea07484705eae303c4b6c3e42252a

# Labels
LABEL \
    org.opencontainers.image.base.name="docker.io/library/${BASE_IMAGE}"\
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.title="dvmgremp/builder" \
    org.opencontainers.image.description="Docker Builder for CI Pipelines" \
    org.opencontainers.image.revision=$REVISION \
    org.opencontainers.image.version=$BUILD_VERSION 


#set timezone of docker image
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#Update and apply any updates to the BASE Image if able to do so
RUN apt update && apt upgrade -y

#install require packages
RUN apt install -y lsb-release curl gnupg
RUN apt install -y lsb-release ca-certificates apt-transport-https software-properties-common

# Add Docker REPO
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN cat /etc/apt/sources.list.d/docker.list

RUN apt update

#install system / build packages needed for pipeline builds
RUN apt-get install -qy --no-install-recommends \
    autoconf \
    build-essential \
    ca-certificates \
    pkg-config \
    wget \
    xvfb \
    curl \
    git \
    ant \
    ssh-client \
    unzip \
    iputils-ping \
    zip \
    jq \
    gettext-base \
    tar \
    parallel \
    gcc \
    openssl \
    openssh-client \
    python3
    
#Install Docker
RUN apt-get install -qy --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin 

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# install docker-compose


# download buildx and move it to the docker plugin folder
# RUN curl -fsSLO https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64
# RUN mkdir -p $HOME/.docker/cli-plugins/
# RUN mv buildx-v${BUILDX_VERSION}.linux-amd64 $HOME/.docker/cli-plugins/docker-buildx
# RUN chmod +x ~/.docker/cli-plugins/docker-buildx

# setup the QEMU emulation environment
#RUN docker run --rm --privileged multiarch/qemu-user-static --reset -p yes; docker buildx create --use

# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh -o install_nvm.sh \
    && echo "${NVM_SHA256} install_nvm.sh" | sha256sum -c - \
    && bash install_nvm.sh \
    && rm -rf install_nvm.sh \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Set node path
ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules

# Default to UTF-8 file.encoding
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LANGUAGE=C.UTF-8

# Xvfb provide an in-memory X-session for tests that require a GUI
ENV DISPLAY=:99

# Set the path.
ENV PATH=$NVM_DIR:$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

RUN mkdir -p /opt/elico/build \
    && sed -i '/[ -z \"PS1\" ] && return/a\\ncase $- in\n*i*) ;;\n*) return;;\nesac' /root/.bashrc \
    && useradd --create-home --shell /bin/bash --uid 1000 pipelines

# Clean up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/elico/build
ENTRYPOINT ["/bin/bash"]