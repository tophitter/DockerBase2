#!/bin/bash
#
# Set PHP Session Storage by passing in 2 args (`Handler` and `Save Path`)
# 

_PHP_SESSION_HANDLER=$1
_PHP_SESSION_SAVE_PATH=$2

# Set Session Handler From Launch Environment var
if [ -v "_PHP_SESSION_HANDLER" ]; then
  echo "Changing session handler to ${_PHP_SESSION_HANDLER}"
  sed -i "s/^session.save_handler.*/session.save_handler = ${_PHP_SESSION_HANDLER}M/" /etc/php/*/apache2/php.ini
  sed -i "s/^session.save_handler.*/session.save_handler = ${_PHP_SESSION_HANDLER}M/" /etc/php/*/fpm/php.ini
fi

# Set Session Save Path From Launch Environment var
if [ -v "_PHP_SESSION_SAVE_PATH" ]; then
  echo "Changing session handler to ${_PHP_SESSION_SAVE_PATH}"
  sed -i "s/^session.save_handler.*/session.save_handler = ${_PHP_SESSION_SAVE_PATH}M/" /etc/php/*/apache2/php.ini
  sed -i "s/^session.save_path.*/session.save_path = ${_PHP_SESSION_SAVE_PATH}M/" /etc/php/*/fpm/php.ini
fi

#session.save_handler=redis
#session.save_path=username:pass@ip:port