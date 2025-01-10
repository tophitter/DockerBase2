#!/bin/bash

# Action args
ACTION_SCRIPT=$2
TARGET_PHP_VERSION=$3

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
                    IMAGE_NAME="${CI_DOCKER_NAMESPACE}/php${PHP_VERSION}-build:bookworm"
                    if [ "$CI_ACTION_PUSH_IMAGES" = true ]; then
                        echo "Creating & Pushing Image ${IMAGE_NAME}"
                        ${DOCKER_BUILD_COMMAND} -t ${IMAGE_NAME} -f ${file}/build/Dockerfile ${file}/build --push
                    else
                        echo "Creating Image ${IMAGE_NAME}"
                        ${DOCKER_BUILD_COMMAND} -t $IMAGE_NAME -f ${file}/build/Dockerfile ${file}/build 
                    fi
                fi
            fi
        fi

        # Look for the Docker file for the apache image
        if [ "${ACTION_SCRIPT}" = "" ] || [ "${ACTION_SCRIPT}" = "all" ] || [ "${ACTION_SCRIPT}" = "apache" ]; then
            if [ -f "${file}/apache/Dockerfile" ]; then
                # Check if there is a .disabled file if so skip build
                if ! [ -f "${file}/apache/.disabled" ]; then
                    IMAGE_NAME="${CI_DOCKER_NAMESPACE}/php${PHP_VERSION}-apache:bookworm"
                    if [ "$CI_ACTION_PUSH_IMAGES" = true ]; then
                        echo "Creating & Pushing Image ${IMAGE_NAME}"
                        ${DOCKER_BUILD_COMMAND} -t ${IMAGE_NAME} -f ${file}/apache/Dockerfile ${file}/apache --push
                    else
                        echo "Creating Image ${IMAGE_NAME}"
                        ${DOCKER_BUILD_COMMAND} -t $IMAGE_NAME -f ${file}/apache/Dockerfile ${file}/apache 
                    fi
                fi
            fi
        fi
    fi
done