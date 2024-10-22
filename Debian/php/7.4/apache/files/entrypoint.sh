#!/bin/bash

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