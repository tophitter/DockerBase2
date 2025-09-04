#!/bin/bash
#
# Datadog Environment Variables Setup Script
# Updates PHP-FPM pool configuration with Datadog settings

CONFIG_FILE="/etc/php/7.2/fpm/pool.d/www.conf"
BACKUP_FILE="${CONFIG_FILE}.backup"

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
    add_or_update_env_var "DD_TRACE_ENABLED" "true"
else
    echo "Disabling Datadog tracing (DD_TRACE_ENABLED=false)"
    add_or_update_env_var "DD_TRACE_ENABLED" "false"
fi

# Always add variables with default fallback values
add_or_update_env_var "DD_TRACE_AGENT_PORT" "\${DD_TRACE_AGENT_PORT:8126}"
add_or_update_env_var "DD_TRACE_SAMPLE_RATE" "\${DD_TRACE_SAMPLE_RATE:1}"
add_or_update_env_var "DD_PROFILING_ENABLED" "\${DD_PROFILING_ENABLED:true}"
add_or_update_env_var "DD_LOGS_INJECTION" "\${DD_LOGS_INJECTION:true}"

# Add variables only if they are set in the environment
if [ -n "${DD_SERVICE}" ]; then
    echo "DD_SERVICE is set: ${DD_SERVICE}"
    add_or_update_env_var "DD_SERVICE" "\${DD_SERVICE}"
fi

if [ -n "${DD_ENV}" ]; then
    echo "DD_ENV is set: ${DD_ENV}"
    add_or_update_env_var "DD_ENV" "\${DD_ENV}"
fi

if [ -n "${DD_VERSION}" ]; then
    echo "DD_VERSION is set: ${DD_VERSION}"
    add_or_update_env_var "DD_VERSION" "\${DD_VERSION}"
fi

if [ -n "${DD_TAGS}" ]; then
    echo "DD_TAGS is set: ${DD_TAGS}"
    add_or_update_env_var "DD_TAGS" "\${DD_TAGS}"
fi

if [ -n "${DD_DBM_PROPAGATION_MODE}" ]; then
    echo "DD_DBM_PROPAGATION_MODE is set: ${DD_DBM_PROPAGATION_MODE}"
    add_or_update_env_var "DD_DBM_PROPAGATION_MODE" "\${DD_DBM_PROPAGATION_MODE}"
fi

echo "Datadog configuration completed successfully"

# Validate the configuration file
echo "Validating PHP-FPM configuration..."
if php-fpm7.2 -t 2>/dev/null; then
    echo "PHP-FPM configuration is valid"
else
    echo "Warning: PHP-FPM configuration validation failed"
fi