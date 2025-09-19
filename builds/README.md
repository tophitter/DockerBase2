# DockerBase Build System

This directory contains the build system for DockerBase Docker images. The build system allows you to create Docker images for different applications, modules, and versions.

## Basic Usage

The main entry point for building images is the `run.sh` script:

```bash
./run.sh --application=<app> --module=<module> --version=<version>
```

Or using short options:

```bash
./run.sh -a <app> -m <module> -v <version>
```

### Required Arguments

- `-a, --application`: The application to build (php, ansible, docker, deploy)
- `-m, --module`: The module to build (build, apache)
- `-v, --version`: The version to build (e.g., 7.2, 7.4, 8.3 for PHP)

### Examples

Build PHP 7.2 Apache image:
```bash
./run.sh --application=php --module=apache --version=7.2
```

Build PHP 7.4 development image:
```bash
./run.sh --application=php --module=build --version=7.4
```

Build all PHP 8.3 images (both apache and build):
```bash
./run.sh --application=php --module=all --version=8.3
```

Build all PHP Apache images:
```bash
./run.sh --application=php --module=apache --version=all
```

Build Ansible image:
```bash
./run.sh --application=ansible
```

Build Docker build image:
```bash
./run.sh --application=docker
```

Build Deploy image:
```bash
./run.sh --application=deploy
```

## Environment Variables

The build system supports various environment variables to customize the build process. You can set these in a `.env` file in the `builds` directory or pass them directly to the `run.sh` script.

### Docker Registry Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `CI_DOCKER_REGISTRY` | Docker registry URL | registry.hub.docker.com |
| `CI_DOCKER_NAMESPACE` | Docker namespace/organization | *required* |
| `CI_DOCKER_USERNAME` | Docker registry username | - |
| `CI_DOCKER_TOKEN` | Docker registry token/password | - |

### Build Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `USE_BUILDX` | Use Docker Buildx for multi-platform builds | true |
| `CI_BUILD_PLATFORMS` | Platforms to build for | linux/amd64,linux/arm64 |
| `CI_BUILD_ARGS` | Additional Docker build arguments | - |
| `IMAGE_TAG_SUFFIX` | Suffix to add to image tags | - |
| `PUSH_IMAGES_TO_REGISTRY` | Push images to registry after build | false |
| `PULL_IMAGES_FROM_REGISTRY` | Pull images from registry for cache | false |
| `USE_PLAIN_LOGS` | Use plain logs for Docker build | false |
| `SHOW_DOCKER_HISTORY` | Show Docker history after build | false |

### Example .env File

```
CI_DOCKER_NAMESPACE=mycompany
CI_DOCKER_USERNAME=myusername
CI_DOCKER_TOKEN=mytoken
PUSH_IMAGES_TO_REGISTRY=true
PULL_IMAGES_FROM_REGISTRY=true
```

## Image Tagging

The build system supports both legacy and new tagging systems. The new tagging system uses mapping files in the `mappings` directory to define additional tags for each image.

### Mapping Files

Mapping files are named `<image-name>.mapping` and contain one tag template per line. For example, `php7.2-apache.mapping` might contain:

```
php-base:p7.2-apache-{{BUILD_ID}}
legacy-web:p7.2-apache-{{BUILD_ID}}
```

The `{{BUILD_ID}}` placeholder is replaced with the actual build ID, which is derived from:
1. Manual override via `BUILD_ID_OVERRIDE` environment variable
2. Git tag (for production builds)
3. Git commit hash (for development builds)

## Disabling Builds

You can disable building specific images by creating a `.disabled` file:

- To disable a PHP version entirely: `Debian/php/<version>/.disabled`
- To disable a specific module: `Debian/php/<version>/<module>/.disabled`

## Advanced Usage

### Multi-platform Builds

By default, the build system uses Docker Buildx to create multi-platform images for both AMD64 and ARM64 architectures. You can customize the target platforms using the `CI_BUILD_PLATFORMS` environment variable.

### Registry Authentication

To push images to a registry, set the following environment variables:
- `CI_DOCKER_USERNAME`
- `CI_DOCKER_TOKEN`
- `PUSH_IMAGES_TO_REGISTRY=true`

### Build Caching

To use images from the registry for build caching, set:
- `PULL_IMAGES_FROM_REGISTRY=true`

This can significantly speed up builds by reusing layers from existing images.

## Troubleshooting

### Common Issues

1. **Missing Docker Namespace**
   - Error: "Missing Docker Namespace!"
   - Solution: Set the `CI_DOCKER_NAMESPACE` environment variable

2. **Authentication Failure**
   - Error: "Error response from daemon: unauthorized"
   - Solution: Check your `CI_DOCKER_USERNAME` and `CI_DOCKER_TOKEN` values

3. **Buildx Not Available**
   - Error: "buildx: command not found"
   - Solution: Install Docker Buildx or set `USE_BUILDX=false`

### Debugging

For more verbose output during builds, set:
```
USE_PLAIN_LOGS=true
```

To inspect the layers of built images, set:
```
SHOW_DOCKER_HISTORY=true
```