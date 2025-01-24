#!/bin/bash

IMAGE_NAME="${CI_DOCKER_NAMESPACE}/ansible-build:bookworm${IMAGE_TAG_SUFFIX}"

if [ "$CI_ACTION_PUSH_IMAGES" = true ]; then
    echo "Creating & Pushing Image ${IMAGE_NAME}"
    docker buildx build ${CI_BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} -t ${IMAGE_NAME} -f ${SCRIPTPATH}/../Debian/Ansible/Dockerfile ${SCRIPTPATH}/../Debian/Ansible --push
else
    echo "Creating Image ${IMAGE_NAME}"
    docker buildx build $CI_BUILD_ARGS --platform=$CI_BUILD_PLATFORMS -t $IMAGE_NAME -f ${SCRIPTPATH}/../Debian/Ansible/Dockerfile ${$SCRIPTPATH}/../Debian/Ansible 
fi
