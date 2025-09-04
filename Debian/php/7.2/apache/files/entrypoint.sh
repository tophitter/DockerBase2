#!/bin/bash
#
# Main Docker APP Entry point that is called to start all Required services and trigger on boot actions pass in by user provided data / env switch
#

# If we have an SSL CRT in the docker file then enable SSL for apache
if [ -f /var/lib/apache/ssl/default-ssl.crt -a -f /var/lib/apache/ssl/default-ssl.key ]; then
  a2enmod ssl
else
  a2dismod ssl
fi

# Set File UPLOAD Limit From Launch Environment var
if [ -v "PHP_UPLOAD_LIMIT" ]; then
  PHP_UPLOAD_LIMIT_SIZE_TYPE="${PHP_UPLOAD_LIMIT_SIZE_TYPE:-M}"
  echo "Changing upload limit to ${PHP_UPLOAD_LIMIT}${PHP_UPLOAD_LIMIT_SIZE_TYPE}"
  sh /opt/set_php_file_upload_limit.sh ${PHP_UPLOAD_LIMIT} ${PHP_UPLOAD_LIMIT_SIZE_TYPE}
fi

# # Configure Datadog settings based on DATADOG_ENABLED flag
# if [ "${DATADOG_ENABLED}" = "true" ]; then
#   echo "Datadog is enabled - configuring Datadog settings"
#   sh /opt/set_datadog.sh
# else
#   echo "Datadog is disabled - skipping Datadog configuration"
#   # Ensure tracing is explicitly disabled
#   export DD_TRACE_ENABLED=false
# fi

# Set Session Handler From Launch Environment var (if SET)
if [ -v "PHP_SESSION_SAVE_PATH" ]; then
  echo "Changing session handler and PATH to ${PHP_SESSION_HANDLER:files} ${PHP_SESSION_SAVE_PATH}"
  sh /opt/set_redis_php_sessions.sh ${PHP_SESSION_HANDLER:files} ${PHP_SESSION_SAVE_PATH}
fi

# Setup Filebeat if script is set
if [ "${ENABLE_FILEBEAT:-false}" = true ]; then
  source /opt/setup_filebeat.sh
else
    echo "Filebeat Disabled."
    # Disable the Filebeat Supervisord App
    if [ -f /etc/supervisor/conf.d/filebeat.conf ]; then
        mv /etc/supervisor/conf.d/filebeat.conf /etc/supervisor/conf.d/filebeat.conf.disabled
    fi
fi

# If the app-entrypoint exists then run it (this is a user passed in action to be run before the app is started)
if [ -f "/app-entrypoint.sh" ]; then
  sh /app-entrypoint.sh
fi

# Start the `supervisord` process
exec supervisord -c /etc/supervisor/supervisord.conf

# If the `after-start-entrypoint.sh` script is found then run it - (this is a user passed in script to run actions after the app has started)
if [ -f "/after-start-entrypoint.sh" ]; then
  sh /after-start-entrypoint.sh
fi
