FROM debian:bookworm

LABEL maintainer="Jason Townsend"

ARG WWWGROUP

#Define versions
ARG MYSQL_PKG_VERSION=0.8.29-1

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
    cron \
    openssh-client \
    apt-utils

# Install MySQL Client
RUN wget https://dev.mysql.com/get/mysql-apt-config_${MYSQL_PKG_VERSION}_all.deb
RUN dpkg -i mysql-apt-config_${MYSQL_PKG_VERSION}_all.deb
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C 
RUN apt update
RUN apt install -y mysql-client

# Install supervisor
RUN apt-get install -yqy --no-install-recommends \
    supervisor \
    nano \
    jq

# Install apache
RUN apt-get install -qy --no-install-recommends \
    apache2 \
    apache2-bin

#set correct user for apache
RUN echo export APACHE_RUN_USER=docker >> /etc/apache2/envvars
RUN echo export APACHE_RUN_GROUP=staff >> /etc/apache2/envvars

#disable appache auto boot as it be controlled by supervisord
RUN update-rc.d apache2 disable

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
    php7.2-dev \
    php7.2-fpm \
    libapache2-mod-php7.2
 
# Clearn up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN update-rc.d php7.2-fpm disable

##Set Some PHP Configs by default
RUN sed -i 's/variables_order = .*/variables_order = "EGPCS"/' /etc/php/7.2/apache2/php.ini
RUN sed -i 's/variables_order = .*/variables_order = "EGPCS"/' /etc/php/7.2/cli/php.ini
RUN sed -i 's/variables_order = .*/variables_order = "EGPCS"/' /etc/php/7.2/fpm/php.ini

# Install composer
#global install of composer if you use php <= 7.2 then use composer version 2.2 else use latest 
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# Clearn up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#add docker user
RUN useradd -m --uid 1000 --gid 50 docker

# copy PHP FPM Configs
COPY files/php/php-fpm.conf /etc/php/7.2/fpm/php-fpm.conf
COPY files/php/pool.d/www.conf /etc/php/7.2/fpm/pool.d/www.conf

#copy vhost file to docker
COPY files/vhosts/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# Copy the apache config file in 
COPY files/apache/apache.conf /etc/apache2/apache2.conf

#Create Default SSL
RUN mkdir -p /var/lib/apache/ssl
RUN openssl req -x509 -nodes -days 365 \
    -subj  "/C=CA/ST=QC/O=Company Inc/CN=example.com" \
    -newkey rsa:2048 -keyout /var/lib/apache/ssl/default-ssl.key \
    -out /var/lib/apache/ssl/default-ssl.crt;

COPY files/vhosts/001-default-ssl.conf /etc/apache2/sites-available/001-default-ssl.conf

# Enable Apache Modules
RUN a2enmod ssl
RUN a2enmod mpm_prefork
RUN a2enmod php7.2

# Enable PHP Mods
RUN phpenmod gd
RUN phpenmod bcmath

# Enable SSL Site
RUN a2ensite 001-default-ssl.conf

#Copy site files to webroot folder
RUN mkdir -p  /var/www/html
RUN chown docker /var/www/html
COPY --chown=docker:staff . /var/www/html

#enable module rewrite
RUN a2enmod rewrite
RUN a2enmod proxy
RUN a2enmod proxy_fcgi
RUN a2enmod proxy_http

#Set docker working folder to webroot
WORKDIR /var/www/html

##### START SERVER
#Copy scripts needed to run the docker image
RUN mkdir -p /supervisord.conf.d
COPY files/entrypoint.sh files/supervisord/supervisord.conf /
COPY files/supervisord/supervisor-exit-event-listener /usr/bin/supervisor-exit-event-listener
RUN chmod +x /entrypoint.sh /usr/bin/supervisor-exit-event-listener

#Remove the docker build files after build, no longer needed in the root of the site
RUN if [ -d "/var/www/html/files" ]; then rm -Rf /var/www/html/files; fi


#call the startup script on docker image run
CMD ["/entrypoint.sh"]

#expose the web port
EXPOSE 80
EXPOSE 443
