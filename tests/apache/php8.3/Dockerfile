FROM dvmgremp/php8.3-apache:bookworm

RUN mkdir -p  /var/www/html/public

# Copy site files to webroot folder
RUN chown docker /var/www/html
COPY --chown=docker:staff . /var/www/html

RUN a2enmod proxy
RUN a2enmod proxy_fcgi
RUN a2enmod proxy_http
RUN a2enmod lbmethod_byrequests

# Set docker working folder to webroot
WORKDIR /var/www/html

############## DEPENDENCIES via COMPOSER ###################
# Get dependencies
USER docker
# Only add private composer if COMPOSER_KEY is provided else ignore
RUN if [ ! -z "$COMPOSER_KEY" ]; then echo "Install Key :: ${COMPOSER_KEY}" & composer config --global --auth http-basic.repo.packagist.com $COMPOSER_USERNAME $COMPOSER_KEY; else echo "NO Key Found"; fi
#Only run composer on the themes and if they have a composer.json file
RUN if [ -f "/var/www/html/composer.json" ]; then composer install --no-dev --working-dir=/var/www/html; fi
USER root

############## DEPENDENCIES via COMPOSER ###################

##### START SERVER #####
COPY docker/app-entrypoint.sh /
RUN chmod +x /app-entrypoint.sh

# Remove the docker folder after used, no longer needed in the root of the site
RUN if [ -d "/var/www/html/docker" ]; then rm -Rf /var/www/html/docker; fi

##### START SERVER #####