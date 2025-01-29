#!/bin/bash

#Workaround to allow environments from AWS to be sent to the Apache Envs file to allow site to use them
#for I in `cat /proc/1/environ | strings`; do echo "export $I"; done >> /etc/apache2/envvars

if [ -f /var/lib/apache/ssl/default-ssl.crt -a -f /var/lib/apache/ssl/default-ssl.key ]; then
  a2enmod ssl
else
  a2dismod ssl
fi

# Fix php settings
if [ -v "PHP_UPLOAD_LIMIT" ]; then
  echo "Changing upload limit to ${PHP_UPLOAD_LIMIT}"
  sed -i "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_LIMIT}M/" /etc/php/*/apache2/php.ini
fi

if [ -f "/app-entrypoint.sh" ]; then
  sh /app-entrypoint.sh
fi

exec supervisord -c /supervisord.conf

if [ -f "/after-start-entrypoint.sh" ]; then
  sh /after-start-entrypoint.sh
fi

# cat /src/.profile