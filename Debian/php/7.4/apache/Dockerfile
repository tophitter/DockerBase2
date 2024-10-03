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
    openssh-client

#Install PHP 7.4 packages
RUN apt-get install -qy --no-install-recommends \
    php7.4 \
    php7.4-curl \
    php7.4-mysql \
    php7.4-gd \
    php7.4-xml \
    php7.4-mbstring \
    php7.4-zip \
    php7.4-bcmath \
    php7.4-cli \
    php7.4-memcached \
    php7.4-imap \
    php7.4-soap \
    php7.4-intl \
    php7.4-readline \
    php7.4-pcov \
    php7.4-msgpack \
    php7.4-igbinary \
    php7.4-redis \
    php7.4-pdo \
    php7.4-dom \
    php7.4-mongodb \
    php7.4-dev
 
############## DEPENDENCIES via COMPOSER ###################

#global install of composer if you use php <= 7.2 then use composer version 2.2 else use latest 
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# Clearn up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#add docker user
RUN useradd -m --uid 1000 --gid 50 docker