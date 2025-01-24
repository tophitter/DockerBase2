#!/bin/bash

IMAGE_NAME="${CI_DOCKER_NAMESPACE}/ci-deploy:bookworm${IMAGE_TAG_SUFFIX}"

if [ "$CI_ACTION_PUSH_IMAGES" = true ]; then
    echo "Creating & Pushing Image ${IMAGE_NAME}"
    docker buildx build ${CI_BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} -t ${IMAGE_NAME} -f ${SCRIPTPATH}/../Debian/Deploy/Dockerfile ${SCRIPTPATH}/../Debian/Deploy --push
else
    echo "Creating Image ${IMAGE_NAME}"
    docker buildx build $CI_BUILD_ARGS --platform=$CI_BUILD_PLATFORMS -t $IMAGE_NAME -f ${SCRIPTPATH}/../Debian/Deploy/Dockerfile ${$SCRIPTPATH}/../Debian/Deploy 
fi
