#!/bin/bash
#
# Main Docker APP Entry point that is called to start all Required services and trigger on boot actions pass in by user provided data / env switch
#

# Configure RemoteIP trusted proxies dynamically
echo "================================================"
echo "Configuring Apache RemoteIP trusted proxies..."
echo "================================================"

# Create remoteip configuration
cat > /etc/apache2/conf-available/remoteip-dynamic.conf << EOF
# Auto-generated RemoteIP configuration for Docker environments
LoadModule remoteip_module modules/mod_remoteip.so

# Default private network ranges (covers most Docker/cloud environments)
RemoteIPTrustedProxy 127.0.0.1/32
RemoteIPTrustedProxy 10.0.0.0/8
RemoteIPTrustedProxy 172.16.0.0/12  
RemoteIPTrustedProxy 192.168.0.0/16

# Additional WSL/Docker network ranges for local development
RemoteIPTrustedProxy 172.26.0.0/20
EOF

# Add custom trusted proxies from environment variable
if [ ! -z "$REMOTEIP_TRUSTED_PROXIES" ]; then
    echo "Adding custom trusted proxies from environment: $REMOTEIP_TRUSTED_PROXIES"
    IFS=',' read -ra PROXY_LIST <<< "$REMOTEIP_TRUSTED_PROXIES"
    for proxy in "${PROXY_LIST[@]}"; do
        # Trim whitespace
        proxy=$(echo "$proxy" | xargs)
        if [ ! -z "$proxy" ]; then
            echo "RemoteIPTrustedProxy $proxy" >> /etc/apache2/conf-available/remoteip-dynamic.conf
            echo "  - Added custom proxy: $proxy"
        fi
    done
fi

# Auto-detect and add the default gateway (load balancer)
GATEWAY_IP=$(ip route show default | awk '/default/ {print $3}')
if [ ! -z "$GATEWAY_IP" ]; then
    echo "RemoteIPTrustedProxy $GATEWAY_IP" >> /etc/apache2/conf-available/remoteip-dynamic.conf
    echo "  - Added gateway IP: $GATEWAY_IP"
fi

# Auto-detect Docker bridge networks and add them
echo "# Auto-detected Docker networks" >> /etc/apache2/conf-available/remoteip-dynamic.conf
ip route | grep -E "docker|br-" | awk '{print $1}' | while read network; do
    if [[ $network =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "RemoteIPTrustedProxy $network" >> /etc/apache2/conf-available/remoteip-dynamic.conf
        echo "  - Added Docker network: $network"
    fi
done

# Finish the configuration file
cat >> /etc/apache2/conf-available/remoteip-dynamic.conf << EOF

# Use Cloudflare's header first, then fall back to X-Forwarded-For
RemoteIPHeader CF-Connecting-IP
RemoteIPHeader X-Forwarded-For
EOF

# Enable the configuration
a2enconf remoteip-dynamic
echo "RemoteIP configuration completed and enabled"
echo "==============================="
echo ""



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

# Configure Datadog settings based on DATADOG_ENABLED flag
if [ "${DATADOG_ENABLED}" = "true" ]; then
  echo "Datadog is enabled - configuring Datadog settings"
  sh /opt/set_datadog.sh
else
  echo "Datadog is disabled - skipping Datadog configuration"
  # Ensure tracing is explicitly disabled
  export DD_TRACE_ENABLED=false
fi

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
