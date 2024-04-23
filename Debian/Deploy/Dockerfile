FROM debian:bookworm

LABEL maintainer="Jason Townsend"

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV TZ=Europe/London

#set timezone of docker image
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#install require packages
RUN apt update && apt upgrade -y && apt install -y lsb-release curl gnupg
RUN apt install -y lsb-release ca-certificates apt-transport-https software-properties-common

#install require packages
RUN apt-get install -qy --no-install-recommends \
    wget  \
    curl \
    unzip \
    openssl \
    git \
    openssh-client
 
# Clearn up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
