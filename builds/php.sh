#!/bin/bash

for file in $SCRIPTPATH/../Debian/php/*; do
    #Check this is a folder
    if [ -d $file ]; then
        if [ -f "${file}/.disabled" ]; then
            continue
        fi

        PHP_VERSION="$(basename -- $file)"
        PHP_VERSION=$(echo "$PHP_VERSION" | tr '[:upper:]' '[:lower:]')

        if [ -f "${file}/Dockerfile" ]; then
            IMAGE_NAME="${CI_DOCKER_NAMESPACE}/php${PHP_VERSION}-build:bookworm"
            if [ "$CI_ACTION_PUSH_IMAGES" = true ]; then
                echo "Creating & Pushing Image ${IMAGE_NAME}"
                docker buildx build ${CI_BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} -t ${IMAGE_NAME} -f ${file}/Dockerfile ${file} --push
            else
                echo "Creating Image ${IMAGE_NAME}"
                docker buildx build $CI_BUILD_ARGS --platform=$CI_BUILD_PLATFORMS -t $IMAGE_NAME -f ${file}/Dockerfile ${file} 
            fi
        fi
    fi
done