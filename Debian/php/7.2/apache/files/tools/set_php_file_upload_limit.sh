#!/bin/bash
#
# Set PHP File Upload Limit by passing in args (`limit`, `Limit Size Type Default to 'MB'`)
# 

_PHP_UPLOAD_LIMIT=$1
_PHP_UPLOAD_LIMIT_SIZE_TYPE="{$2:'M'}"

# Set File UPLOAD Limit
if [ -v "_PHP_UPLOAD_LIMIT" ]; then
  echo "Changing upload limit to ${_PHP_UPLOAD_LIMIT}"

  # Maximum allowed size for uploaded files.
  sed -i "s/^upload_max_filesize.*/upload_max_filesize = ${_PHP_UPLOAD_LIMIT}${_PHP_UPLOAD_LIMIT_SIZE_TYPE}/" /etc/php/*/apache2/php.ini
  sed -i "s/^upload_max_filesize.*/upload_max_filesize = ${_PHP_UPLOAD_LIMIT}${_PHP_UPLOAD_LIMIT_SIZE_TYPE}/" /etc/php/*/fpm/php.ini

  # Must be greater than or equal to upload_max_filesize
  sed -i "s/^post_max_size.*/post_max_size = ${_PHP_UPLOAD_LIMIT}${_PHP_UPLOAD_LIMIT_SIZE_TYPE}/" /etc/php/*/apache2/php.ini
  sed -i "s/^post_max_size.*/post_max_size = ${_PHP_UPLOAD_LIMIT}${_PHP_UPLOAD_LIMIT_SIZE_TYPE}/" /etc/php/*/fpm/php.ini
fi
