FROM debian:bookworm

LABEL maintainer="Jason Townsend"

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV TZ=Europe/London

#set timezone of docker image
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#install require packages
RUN apt update && apt upgrade -y && apt install -y lsb-release curl gnupg

# Add Ondrej's repo source and signing key along with dependencies
RUN export LC_ALL=en_GB.UTF-8 && export LANG=en_GB.UTF-8 && apt-get install -y ca-certificates apt-transport-https software-properties-common
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
    ca-certificates

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

# Install NVM
SHELL ["/bin/bash", "--login", "-c"]
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.7/install.sh | bash
RUN nvm install node

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