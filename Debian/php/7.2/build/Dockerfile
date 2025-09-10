ARG BASE_IMAGE=debian:bookworm

FROM ${BASE_IMAGE}

LABEL maintainer="Jason Townsend"

# Args
ARG BUILD_DATE
ARG REVISION
ARG BUILD_VERSION
ARG IMAGE_TITLE
ARG IMAGE_DESC
ARG DEBIAN_FRONTEND=noninteractive

# Need to defined this after the from as well so it can be used in this step
ARG BASE_IMAGE

#Environment Variables
ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV TZ=Europe/London

ENV NODE_VERSION=18.16.1 \
    NVM_DIR=/root/.nvm \
    NVM_VERSION=0.39.2 \
    NVM_SHA256=c1e672cd63737cd3e166ad43dffcb630a3bea07484705eae303c4b6c3e42252a

# Labels
LABEL \
    org.opencontainers.image.base.name="docker.io/library/${BASE_IMAGE}"\
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.title="${IMAGE_TITLE}" \
    org.opencontainers.image.description="${IMAGE_DESC}" \
    org.opencontainers.image.revision=$REVISION \
    org.opencontainers.image.version=$BUILD_VERSION 

#set timezone of docker image
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#Update and apply any updates to the BASE Image if able to do so
RUN apt update && apt upgrade -y

#install require packages
RUN apt install -y lsb-release curl gnupg
RUN apt install -y lsb-release ca-certificates apt-transport-https software-properties-common

# Add Ondrej's repo source and signing key along with dependencies
RUN export LC_ALL=en_GB.UTF-8 && export LANG=en_GB.UTF-8 
#RUN curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
RUN curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb
RUN dpkg -i /tmp/debsuryorg-archive-keyring.deb
RUN sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
RUN cat /etc/apt/sources.list.d/php.list
RUN apt update

#install require packages
RUN apt-get install -qy --no-install-recommends \
    wget  \
    openssl \
    git \
    unzip \
    curl \
    openssh-client \
    ca-certificates \
    jq

RUN update-ca-certificates

#Install PHP 7.2 packages
RUN apt-get install -qy --no-install-recommends \
    php7.2 \
    php7.2-curl \
    php7.2-mysql \
    php7.2-gd \
    php7.2-xml \
    php7.2-mbstring \
    php7.2-zip \
    php7.2-bcmath \
    php7.2-cli \
    php7.2-memcached \
    php7.2-imap \
    php7.2-soap \
    php7.2-intl \
    php7.2-readline \
    php7.2-pcov \
    php7.2-msgpack \
    php7.2-igbinary \
    php7.2-redis \
    php7.2-pdo \
    php7.2-dom \
    php7.2-mongodb \
    php7.2-dev
 
############## DEPENDENCIES via COMPOSER ###################

#global install of composer if you use php <= 7.2 then use composer version 2.2 else use latest 
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh -o install_nvm.sh \
    && echo "${NVM_SHA256} install_nvm.sh" | sha256sum -c - \
    && bash install_nvm.sh \
    && rm -rf install_nvm.sh \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm install 14.17.5 \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Set node path
ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules

# Set the path.
ENV PATH=$NVM_DIR:$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

#Insall AWS CLI 
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
#Remove the downloaded ZIP and extracted folder file
RUN rm awscliv2.zip
RUN rm -r ./aws

# Clean up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#add docker user
RUN useradd -m --uid 1000 --gid 50 docker