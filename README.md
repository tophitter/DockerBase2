# DockerBase

## Overview

DockerBase is a comprehensive Docker image building system designed to create standardized, production-ready Docker environments for PHP applications. It provides a collection of base images with different PHP versions (7.2, 7.4, 8.3) and configurations (Apache, development builds) that can be extended for specific application needs.

## Key Features

- **Multiple PHP Versions**: Supports PHP 7.2, 7.4, and 8.3
- **Production-Ready Configurations**: Optimized for performance and security
- **Standardized Environments**: Consistent configuration across all environments
- **Dynamic PHP-FPM Pool Settings**: Automatically optimizes PHP-FPM worker settings based on available resources
- **Monitoring Integration**: Built-in support for Datadog and Filebeat
- **Session Handling**: Configurable Redis session storage
- **SSL Support**: Pre-configured SSL capabilities
- **Customizable**: Extensive environment variable configuration options

## Available Images

### PHP Apache Images

Production-ready PHP environments with Apache:

- PHP 7.2 + Apache
- PHP 7.4 + Apache
- PHP 8.3 + Apache

### Development/Build Images

PHP environments with additional development tools:

- PHP 7.2 Build
- PHP 7.4 Build
- PHP 8.3 Build

### Additional Images

- Ansible: For infrastructure automation
- Deploy: For deployment operations
- DockerBuild: For Docker image building operations

## Environment Variables

DockerBase images support numerous environment variables for customization:

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | Europe/London |
| `REMOTEIP_TRUSTED_PROXIES` | Comma-separated list of trusted proxy IPs | Auto-detected |
| `PHP_UPLOAD_LIMIT` | PHP file upload size limit | - |
| `PHP_UPLOAD_LIMIT_SIZE_TYPE` | Unit for upload limit (K, M, G) | M |
| `DATADOG_ENABLED` | Enable Datadog integration | false |
| `DD_TRACE_ENABLED` | Enable Datadog tracing | false |
| `DD_AGENT_HOST` | Datadog agent hostname | localhost |
| `DD_TRACE_AGENT_PORT` | Datadog trace agent port | 8126 |
| `DD_TRACE_SAMPLE_RATE` | Datadog trace sampling rate | 1 |
| `DD_PROFILING_ENABLED` | Enable Datadog profiling | 1 |
| `DD_LOGS_INJECTION` | Enable Datadog logs injection | 1 |
| `DD_DBM_PROPAGATION_MODE` | Datadog database monitoring propagation mode | full |
| `DD_SERVICE` | Service name for Datadog | - |
| `DD_ENV` | Environment name for Datadog | FILEBEAT_ENVIRONMENT or APP_ENV |
| `DD_VERSION` | Application version for Datadog | - |
| `DD_TAGS` | Custom tags for Datadog | - |
| `PHP_SESSION_HANDLER` | PHP session handler | files |
| `PHP_SESSION_SAVE_PATH` | Path or connection string for session storage | - |
| `ENABLE_FILEBEAT` | Enable Filebeat log shipping | false |
| `ELASTIC_LOGSTASH_HOSTS` | Logstash hosts for Filebeat | - |
| `FILEBEAT_SERVICE_ID_NAME` | Service identifier for Filebeat logs | Container hostname |
| `FILEBEAT_ENVIRONMENT` | Environment identifier for Filebeat logs | dev |
| `FILEBEAT_DOMAIN_HOST` | Domain host identifier for Filebeat logs | Container hostname |
| `FILEBEAT_GENERATE_CERT` | Generate SSL certificates for Filebeat | false |
| `LOGSTASH_SSL_CA_CERT` | CA certificate for Filebeat SSL (when generating certs) | - |
| `LOGSTASH_SSL_CA_KEY` | CA key for Filebeat SSL (when generating certs) | - |
| `FILEBEAT_SSL_CERT` | SSL certificate for Filebeat (when not generating) | - |
| `FILEBEAT_SSL_CERT_KEY` | SSL key for Filebeat (when not generating) | - |
| `DYNAMIC_POOL` | Enable dynamic PHP-FPM pool settings | false |
| `OPCACHE_ENABLE` | Enable PHP OPcache | 1 |
| `OPCACHE_MEMORY_CONSUMPTION` | OPcache memory consumption | 128 |
| `OPCACHE_INTERNED_STRINGS_BUFFER` | OPcache interned strings buffer | 8 |
| `OPCACHE_MAX_ACCELERATED_FILES` | OPcache max accelerated files | 10000 |
| `OPCACHE_VALIDATE_TIMESTAMPS` | OPcache validate timestamps | 1 |
| `OPCACHE_REVALIDATE_FREQ` | OPcache revalidate frequency | 2 |

## Usage Examples

### Basic Usage

To run a PHP 7.2 Apache container:

```bash
docker run -d -p 80:80 -p 443:443 -v /path/to/app:/var/www/html your-registry/php-base:p7.2-apache
```

### With Redis Session Storage

```bash
docker run -d -p 80:80 \
  -e PHP_SESSION_HANDLER=redis \
  -e PHP_SESSION_SAVE_PATH="tcp://redis-host:6379?auth=password" \
  -v /path/to/app:/var/www/html \
  your-registry/php-base:p7.2-apache
```

### With Dynamic PHP-FPM Pool Settings

```bash
docker run -d -p 80:80 \
  -e DYNAMIC_POOL=true \
  -v /path/to/app:/var/www/html \
  your-registry/php-base:p7.2-apache
```

### With Datadog Monitoring

```bash
docker run -d -p 80:80 \
  -e DATADOG_ENABLED=true \
  -e DD_TRACE_ENABLED=true \
  -e DD_AGENT_HOST=datadog-agent \
  -e DD_TRACE_AGENT_PORT=8126 \
  -e DD_SERVICE=my-php-service \
  -e DD_ENV=production \
  -e DD_VERSION=1.0.0 \
  -e DD_PROFILING_ENABLED=1 \
  -e DD_LOGS_INJECTION=1 \
  -e DD_TAGS="team:backend,application:web" \
  -v /path/to/app:/var/www/html \
  your-registry/php-base:p7.2-apache
```

### With Filebeat Log Shipping

```bash
docker run -d -p 80:80 \
  -e ENABLE_FILEBEAT=true \
  -e ELASTIC_LOGSTASH_HOSTS="logstash-host:5044" \
  -e FILEBEAT_SERVICE_ID_NAME="my-service" \
  -e FILEBEAT_ENVIRONMENT="production" \
  -v /path/to/app:/var/www/html \
  your-registry/php-base:p7.2-apache
```

### With Filebeat and SSL Certificate Generation

```bash
docker run -d -p 80:80 \
  -e ENABLE_FILEBEAT=true \
  -e ELASTIC_LOGSTASH_HOSTS="logstash-host:5044" \
  -e FILEBEAT_GENERATE_CERT=true \
  -e LOGSTASH_SSL_CA_CERT="$(cat /path/to/ca.crt)" \
  -e LOGSTASH_SSL_CA_KEY="$(cat /path/to/ca.key)" \
  -v /path/to/app:/var/www/html \
  your-registry/php-base:p7.2-apache
```

## Custom Entrypoints

DockerBase supports custom entrypoint scripts:

- `/app-entrypoint.sh`: Executed before the main application starts
- `/after-start-entrypoint.sh`: Executed after the main application starts

Example:

```bash
docker run -d -p 80:80 \
  -v /path/to/app:/var/www/html \
  -v /path/to/custom-entrypoint.sh:/app-entrypoint.sh \
  your-registry/php-base:p7.2-apache
```

## Building Images

See the [builds/README.md](builds/README.md) file for detailed instructions on building DockerBase images.

## Testing

The `tests` directory contains example applications for testing the different PHP versions and configurations.
