FROM debian:bookworm

LABEL maintainer="Jason Townsend"

ARG WWWGROUP

#Define versions
ARG MYSQL_PKG_VERSION=0.8.29-1

# Redis Connection string for PHP Session Store if it baked in
ARG SessionRedisConnectionString

ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    TZ=Europe/London

#set timezone of docker image
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install required packages in one step
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    lsb-release curl gnupg wget openssl git unzip cron openssh-client apt-utils less supervisor nano jq apache2 apache2-bin \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add Ondrej's repo source and signing key along with dependencies
RUN export LC_ALL=en_GB.UTF-8 && export LANG=en_GB.UTF-8 && apt-get update && apt-get install -y ca-certificates apt-transport-https software-properties-common
RUN curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/deb.sury.org-php.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/php.list && apt-get update

# Install MySQL Client with non-interactive debconf frontend
RUN export DEBIAN_FRONTEND=noninteractive && \
    wget https://dev.mysql.com/get/mysql-apt-config_${MYSQL_PKG_VERSION}_all.deb && \
    dpkg -i mysql-apt-config_${MYSQL_PKG_VERSION}_all.deb && \
    apt-get update && apt-get install -y mysql-client && \
    rm -f mysql-apt-config_${MYSQL_PKG_VERSION}_all.deb && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#set correct user for apache
RUN echo export APACHE_RUN_USER=docker >> /etc/apache2/envvars
RUN echo export APACHE_RUN_GROUP=staff >> /etc/apache2/envvars

#disable Apache auto boot as it be controlled by supervisord
RUN update-rc.d apache2 disable

# Install PHP 7.2 and extensions in one step
RUN apt-get update && apt install -y --no-install-recommends \
    php7.2 php7.2-curl php7.2-mysql php7.2-gd php7.2-xml php7.2-mbstring \
    php7.2-zip php7.2-bcmath php7.2-cli php7.2-memcached php7.2-imap \
    php7.2-soap php7.2-intl php7.2-readline php7.2-pcov php7.2-msgpack \
    php7.2-igbinary php7.2-redis php7.2-pdo php7.2-dom php7.2-mongodb \
    php7.2-dev php7.2-fpm libapache2-mod-php7.2 && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
 
### Install Filebeat requires pkg `apt-transport-https` to be installed before this action.
ARG ELASTIC_KEYRING_PATH="/usr/share/keyrings/elasticsearch-keyring.gpg"
ARG ELASTIC_REPO_FILE="/etc/apt/sources.list.d/elastic-8.x.list"
ARG ELASTIC_KEYRING_PATH_REPO_URL="https://artifacts.elastic.co/"
ARG ELASTIC_KEYRING_REPO_ENDPOINT_GPG="$ELASTIC_KEYRING_PATH_REPO_URL/GPG-KEY-elasticsearch"
ARG ELASTIC_KEYRING_REPO_ENDPOINT_REPO="$ELASTIC_KEYRING_PATH_REPO_URL/packages/8.x/apt"

# Env that needed to be passed in
ENV ELASTIC_LOGSTASH_HOSTS=;

# Install Filebeat in one step
RUN mkdir -p "$(dirname "$ELASTIC_KEYRING_PATH")" && \
    curl -fsSL $ELASTIC_KEYRING_REPO_ENDPOINT_GPG | gpg --dearmor -o $ELASTIC_KEYRING_PATH && \
    echo "deb [signed-by=$ELASTIC_KEYRING_PATH] $ELASTIC_KEYRING_REPO_ENDPOINT_REPO stable main" \
    | tee $ELASTIC_REPO_FILE && apt-get update && apt-get install -y filebeat && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY files/elastic/filebeat/filebeat.yml /etc/filebeat/filebeat.yml

# Clean up packages and cache id present
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

# Clean up packages and cache
RUN apt -y autoremove \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#add docker user
RUN useradd -m --uid 1000 --gid 50 docker

# copy PHP FPM Configs
COPY files/php/fpm/php-fpm.conf /etc/php/7.2/fpm/php-fpm.conf
COPY files/php/fpm/pool.d/www.conf /etc/php/7.2/fpm/pool.d/www.conf

# Add Empty lline at the end of the confing file if not already added else this will break the startup continer
RUN [ -n "$(tail -c1 /etc/php/7.2/fpm/pool.d/www.conf)" ] && echo "" >> /etc/php/7.2/fpm/pool.d/www.conf || true

#copy vhost file to docker
COPY files/vhosts/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# Copy the apache config file in 
COPY files/apache/apache.conf /etc/apache2/apache2.conf

# Generate SSL Certificate in one step
RUN mkdir -p /var/lib/apache/ssl && \
    openssl req -x509 -nodes -days 365 \
    -subj "/C=CA/ST=QC/O=Company Inc/CN=example.com" \
    -newkey rsa:2048 -keyout /var/lib/apache/ssl/default-ssl.key \
    -out /var/lib/apache/ssl/default-ssl.crt

COPY files/vhosts/001-default-ssl.conf /etc/apache2/sites-available/001-default-ssl.conf

# Enable Apache Modules
RUN a2enmod ssl mpm_prefork
RUN a2enmod php7.2

# Enable PHP Mods
RUN phpenmod gd bcmath

# Enable SSL Site
RUN a2ensite 001-default-ssl.conf

#Copy site files to web-root folder
RUN mkdir -p  /var/www/html
RUN chown docker /var/www/html
COPY --chown=docker:staff . /var/www/html

# Setup Logs and Redirect to docker container stdout
RUN mkdir -p  /var/www/logs
RUN touch /var/www/logs/php_error.log
RUN chown -R docker:staff /var/www/logs

# RUN ln -sf /proc/self/fd/2 /var/www/logs/php_error.log

#enable module rewrite
RUN a2enmod headers
RUN a2enmod http2
RUN a2enmod remoteip
RUN a2enmod rewrite
RUN a2enmod proxy
RUN a2enmod proxy_fcgi
RUN a2enmod proxy_http
RUN a2enmod proxy_balancer
RUN a2enmod lbmethod_byrequests
RUN a2enmod status

#Set docker working folder to web-root
WORKDIR /var/www/html

##### START SERVER

# Ensure supervisor directories exist before copying files
RUN mkdir -p /etc/supervisor/ /etc/supervisor/conf.d/

#Copy any extra supervisor apps to the conf file
COPY files/supervisord.conf.d/*.conf /etc/supervisor/conf.d/

# Copy supervisor config to etc
COPY files/supervisord/supervisord.conf /etc/supervisor/supervisord.conf

#Copy the Entrypointpoint script to root of the site
COPY files/entrypoint.sh /

# Copy Supervisor Event Listener for exit event codes to auto restart apps if they crash.
COPY files/supervisord/supervisor-exit-event-listener /usr/bin/supervisor-exit-event-listener

RUN chmod +x /entrypoint.sh /usr/bin/supervisor-exit-event-listener

# Install Datadog PHP extension
RUN curl -LO https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php
RUN php datadog-setup.php --php-bin=all --enable-appsec --enable-profiling

# Set default Datadog tracing to disabled
ENV DD_TRACE_ENABLED=false

# copy tools scripts to /opt
COPY files/tools /opt/
RUN chmod +x /opt/*.sh

#Remove the docker build files after build, no longer needed in the root of the site
RUN if [ -d "/var/www/html/files" ]; then rm -Rf /var/www/html/files; fi

# If Redis Session is basked into the Build Args then runs setup else ignore
RUN if [[ -z "$SessionRedisConnectionString" ]] ; then sh /opt/set_redis_php_sessions.sh redis $SessionRedisConnectionString ; fi

#call the startup script on docker image run
CMD ["/entrypoint.sh"]

#expose the web port
EXPOSE 80
EXPOSE 443
