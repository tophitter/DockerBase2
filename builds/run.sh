#!/bin/bash
#
#
# exmaple useage to build the php 7.2 apache images  ./run.sh php apache 7.2 

set -a

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Include env if the file is found
if [ -f "${SCRIPTPATH}/.env" ]; then
  source ${SCRIPTPATH}/.env
fi

BUILD_SCRIPT=$1

DEV_MODE="${DEV_MODE:false}"
export DEV_MODE;

CI_DOCKER_REGISTRY="${CI_DOCKER_REGISTRY:-registry.hub.docker.com}"
export CI_DOCKER_REGISTRY;

CI_DOCKER_NAMESPACE="${CI_DOCKER_NAMESPACE:-}"
export CI_DOCKER_NAMESPACE

CI_DOCKER_USERNAME="${CI_DOCKER_USERNAME:-}"
export CI_DOCKER_USERNAME

CI_DOCKER_TOKEN="${CI_DOCKER_TOKEN:-}"
export CI_DOCKER_TOKEN

CI_BUILD_PLATFORMS="${CI_BUILD_PLATFORMS:-linux/amd64,linux/arm64}"
export CI_BUILD_PLATFORMS

CI_BUILD_ARGS="${CI_BUILD_ARGS:-}"
export CI_BUILD_ARGS

CI_ACTION_PUSH_IMAGES=false
export CI_ACTION_PUSH_IMAGES

CI_ACTION_PULL_IMAGES=false
export CI_ACTION_PULL_IMAGES

#This is a required argument so if not set or empty stop build
if [ -z ${BUILD_SCRIPT+x} ] || [ -z "${BUILD_SCRIPT}" ]; then
    echo "Missing target build script!"
    exit 1
fi

if [ ! -f "${SCRIPTPATH}/${BUILD_SCRIPT}.sh" ]; then
  echo "Build script for target '${SCRIPTPATH}/${BUILD_SCRIPT}.sh' NOT FOUND"
  exit 1
fi

#This is a required argument so if not set or empty stop build
if [ -z ${CI_DOCKER_NAMESPACE+x} ] || [ -z "${CI_DOCKER_NAMESPACE}" ]; then
    echo "Missing Docker Namespace!"
    exit 1
fi

# Check if in Dev Mode
if [ "$DEV_MODE" = true ]; then
  echo "Dev MODE Enabled Prevent Pushing to docker hub"
else
  #If we have Docker Username and password login to docker
  if [ "${CI_DOCKER_REGISTRY}" == "" ]; then
    echo "AWS Login"
    
  else
    if [ ! -z ${CI_DOCKER_USERNAME+x} ] && [ "${CI_DOCKER_USERNAME}" != "" ] && [ ! -z ${CI_DOCKER_TOKEN+x} ] && [ "${CI_DOCKER_TOKEN}" != "" ]; then
        echo "logging into registry"
        echo "${CI_DOCKER_TOKEN}" | docker login --username=$CI_DOCKER_USERNAME --password-stdin $CI_DOCKER_REGISTRY
        export CI_ACTION_PUSH_IMAGES=true
    fi
  fi
fi

DOCKER_BUILD_COMMAND="docker buildx build ${CI_BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS}";
if [ "$DEV_MODE" = true ]; then
  DOCKER_BUILD_COMMAND="docker build ${CI_BUILD_ARGS}";
else
  docker buildx create --name base_img_builder --use
fi

echo ">>> Running build script '${BUILD_SCRIPT}.sh'";
${SCRIPTPATH}/${BUILD_SCRIPT}.sh "$@"
ret_code=$?

if [ "$DEV_MODE" = false ]; then
  if [ "$BUILD_DELETE_BUILDX_BUILDER_AFTER_BUILD" = true ]; then
      echo ">>> Removeing base_img_builder"
      docker buildx rm base_img_builder
  fi
fi

exit $ret_code