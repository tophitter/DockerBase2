#!/bin/bash
#
# Datadog Environment Variables Setup Script
# Updates PHP-FPM pool configuration with Datadog settings

CONFIG_FILE="/etc/php/7.2/fpm/pool.d/www.conf"
BACKUP_FILE="${CONFIG_FILE}.backup"

echo ""
echo "================================"
echo "Datadog Configuration"
echo "================================"
echo ""

# Create backup of original config file
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Creating backup of $CONFIG_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

# Function to add or update environment variable in config
add_or_update_env_var() {
    local var_name="$1"
    local var_value="$2"
    local config_line="env[$var_name] = $var_value"
    
    echo "$var_name is set: $config_line"

    # Check if the line already exists (commented or uncommented)
    if grep -q "^[[:space:]]*;*[[:space:]]*env\[$var_name\]" "$CONFIG_FILE"; then
        # Replace existing line
        sed -i "s|^[[:space:]]*;*[[:space:]]*env\[$var_name\].*|$config_line|" "$CONFIG_FILE"
        echo "Updated: $config_line"
    else
        # Add new line at the end of the file
        echo "$config_line" >> "$CONFIG_FILE"
        echo "Added: $config_line"
    fi
}

echo "Setting up Datadog environment variables in PHP-FPM configuration"

# Enable/Disable Datadog tracing based on DATADOG_ENABLED
if [ "${DATADOG_ENABLED}" = "true" ]; then
    echo "Enabling Datadog tracing (DD_TRACE_ENABLED=true)"
    add_or_update_env_var "DD_TRACE_ENABLED" "1"
else
    echo "Disabling Datadog tracing (DD_TRACE_ENABLED=false)"
    add_or_update_env_var "DD_TRACE_ENABLED" "0"
fi

# Always add variables with default fallback values
add_or_update_env_var "DD_AGENT_HOST" "${DD_AGENT_HOST:-localhost}"
add_or_update_env_var "DD_TRACE_AGENT_PORT" "${DD_TRACE_AGENT_PORT:-8126}"
add_or_update_env_var "DD_TRACE_SAMPLE_RATE" "${DD_TRACE_SAMPLE_RATE:-1}"
add_or_update_env_var "DD_PROFILING_ENABLED" "${DD_PROFILING_ENABLED:-1}"
add_or_update_env_var "DD_LOGS_INJECTION" "${DD_LOGS_INJECTION:-1}"
add_or_update_env_var "DD_DBM_PROPAGATION_MODE" "${DD_DBM_PROPAGATION_MODE:-full}"

# Add variables only if they are set in the environment (these do nto have a default as they need to be set)
if [ -n "${DD_SERVICE}" ]; then
    add_or_update_env_var "DD_SERVICE" "${DD_SERVICE}"
fi

if [ -n "${DD_ENV}" ]; then
    add_or_update_env_var "DD_ENV" "${DD_ENV}"
else
    # Fall back to filebeat env if set
    if [ -n "$FILEBEAT_ENVIRONMENT" ]; then
        add_or_update_env_var "DD_ENV" "${FILEBEAT_ENVIRONMENT}"
    else
        # Fallback to APP_ENV if set
        if [ -n "$APP_ENV" ]; then
            add_or_update_env_var "DD_ENV" "${APP_ENV}"
        fi
    fi
fi

if [ -n "${DD_VERSION}" ]; then
    add_or_update_env_var "DD_VERSION" "${DD_VERSION}"
fi

if [ -n "${DD_TAGS}" ]; then
    add_or_update_env_var "DD_TAGS" "${DD_TAGS}"
fi

echo "Datadog configuration completed successfully"
echo ""
echo "================================"
echo ""

# Validate the configuration file
echo "Validating PHP-FPM configuration..."
if php-fpm7.2 -t 2>/dev/null; then
    echo "PHP-FPM configuration is valid"
else
    echo "Warning: PHP-FPM configuration validation failed"
fi