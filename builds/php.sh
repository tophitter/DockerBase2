#!/bin/bash

if [ -z ${SCRIPTPATH+x} ] || [ -z "${SCRIPTPATH}" ]; then
    echo "Missing Script Path, Make sure you are calling the 'run.sh' and not 'php.sh'!"
    exit 1
fi

# Action args
ACTION_SCRIPT="${BUILD_EXTRA_MODULE:-}"
TARGET_PHP_VERSION="${BUILD_EXTRA_VERSION}"

#If PHP Version is `all` then empty the var as empty string default will build all versions
if [ "${TARGET_PHP_VERSION}" == "all" ]; then
    TARGET_PHP_VERSION="";
fi

for file in $SCRIPTPATH/../Debian/php/*; do
    #Check this is a folder
    if [ -d $file ]; then
        # Check if there is a .disabled file if so skip build
        if [ -f "${file}/.disabled" ]; then
            echo "${file} is disabled, Skipping..."
            continue
        fi

        # Build the PHP Version from the folder name
        PHP_VERSION="$(basename -- $file)"
        # Make the version lowercase
        PHP_VERSION=$(echo "$PHP_VERSION" | tr '[:upper:]' '[:lower:]')
        if [ "${TARGET_PHP_VERSION}" != "" ] && [ "${TARGET_PHP_VERSION}" != "${PHP_VERSION}" ]; then
            echo "PHP Version: ${PHP_VERSION} not match Target version: ${TARGET_PHP_VERSION}. Skipping..."
            continue;
        fi

        # Look for the Docker file for the build image
        if [ "${ACTION_SCRIPT}" = "" ] || [ "${ACTION_SCRIPT}" = "all" ] || [ "${ACTION_SCRIPT}" = "build" ]; then
            if [ -f "${file}/build/Dockerfile" ]; then
                # Check if there is a .disabled file if so skip build
                if ! [ -f "${file}/build/.disabled" ]; then
                    build_image "php${PHP_VERSION}-build" "bookworm" "Debian/php/${PHP_VERSION}/build"
                fi
            fi
        fi

        # Look for the Docker file for the apache image
        if [ "${ACTION_SCRIPT}" = "" ] || [ "${ACTION_SCRIPT}" = "all" ] || [ "${ACTION_SCRIPT}" = "apache" ]; then
            if [ -f "${file}/apache/Dockerfile" ]; then
                # Check if there is a .disabled file if so skip build
                if ! [ -f "${file}/apache/.disabled" ]; then
                    build_image "php${PHP_VERSION}-apache" "bookworm" "Debian/php/${PHP_VERSION}/apache"
                fi
            fi
        fi
    fi
done