#!/bin/bash

if [ -z ${SCRIPTPATH+x} ] || [ -z "${SCRIPTPATH}" ]; then
    echo "Missing Script Path, Make sure you are calling the 'run.sh' and not 'functions.sh'!"
    exit 1
fi

fn_die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
export -f fn_die

fn_needs_arg() { if [ -z "$OPTARG" ]; then fn_die "No arg for --$OPT option"; fi; }
export -f fn_needs_arg

fn_exists() {
  [ $(type -t "$1")"" == 'function' ]
}
export -f fn_exists

function build_app_deploy(){
    # Build Docker image pass in arguments: image_name, image_tag, path_to_docker_file
    build_image "ci-deploy" "bookworm" "Debian/Deploy"
}

function build_app_docker(){
    # Build Docker image pass in arguments: image_name, image_tag, path_to_docker_file
    build_image "ci-builder" "docker-bookworm" "Debian/DockerBuild"
}

function build_app_ansible(){
    # Build Docker image pass in arguments: image_name, image_tag, path_to_docker_file
    build_image "ansible-build" "bookworm" "Debian/Ansible"
    #build_image "ci-builder" "ansible-bookworm" "Debian/Ansible"
}

function docker_tag_exists() {
  if [ "${CI_DOCKER_REGISTRY}" == "registry-1.docker.io" ]; then
    curl -s -f -lSL https://hub.docker.com/v2/repositories/$1/tags/$2 > /dev/null 
  fi
}
export -f docker_tag_exists


#Login code
function docker_hub_login(){
    echo "docker_hub_login Called"
    TMP_USERNAME=$1
    TMP_TOKEN=$2
    TMP_REGISTRY=$3
    
    if [ ! -z ${TMP_USERNAME+x} ] && [ "${TMP_USERNAME}" != "" ] && [ ! -z ${TMP_TOKEN+x} ] && [ "${TMP_TOKEN}" != "" ]; then
        echo "logging into registry"
        if [ "$CI_ACTION_PIEPLINE" = true ]; then
          echo "CI PIPELINE LOGIN CALLED"
          if [ "${TMP_REGISTRY}" == "registry-1.docker.io" ]; then
            # Login is default docker hub, do not provide the redistry url on login
            docker login --username $TMP_USERNAME --password $TMP_TOKEN
          else
            # login nto useing the default docker hub registry provide redistry url on login
            docker login --username $TMP_USERNAME --password $TMP_TOKEN $TMP_REGISTRY
          fi
        else
          echo "${TMP_TOKEN}" | docker login --username=$TMP_USERNAME --password-stdin $TMP_REGISTRY
        fi
        export PUSH_IMAGES_TO_REGISTRY=true
    fi
}
export -f docker_hub_login

function docker_aws_login(){
    echo "TODO AWS Login";
    exit 1
}
export -f docker_aws_login

# Build Docker image pass in arguments: image_name, image_tag, path_to_docker_file
function build_image(){
  tName=$1
  tTag=$2
  tPath=$3

  REPO="${CI_DOCKER_NAMESPACE}/${tName}"
  TAG="${tTag}${IMAGE_TAG_SUFFIX}"
  CACHE_ARG="";

  IMAGE_NAME="${REPO}:${TAG}"
  BUILD_ARGS="${CI_BUILD_ARGS} ${COMMON_BUILD_ARGS} --build-arg BUILD_VERSION=${TAG}"

  # if plain logging is enabled then add --progress plain as a build arg
  if [ "$USE_PLAIN_LOGS" = true ]; then
    BUILD_ARGS=" ${BUILD_ARGS} --progress plain"
  fi

  if [ "${PULL_IMAGES_FROM_REGISTRY}" = true ]; then
    CACHE_ARG="--cache-from ${IMAGE_NAME}"

    #Send empty echo to make a new line in the output
    echo "";

    echo "Pull Laest version of ${IMAGE_NAME} from registry if found"
    if docker_tag_exists $REPO $TAG; then
        docker pull ${IMAGE_NAME} 
    else
        echo "";
        echo "${IMAGE_NAME} not found in registry no cache will be used"
    fi
  else
    echo "Cache Not Enabled, Skiping pulling image from registry"
  fi

  #Send empty echo to make a new line in the output
  echo "";
  DOCKER_ARGS_EX=""

  if [ "${USE_BUILDX}" = true ]; then
    if [ "${PUSH_IMAGES_TO_REGISTRY}" = true ]; then
        echo "buildx Creating Image: ${IMAGE_NAME} and publishing to registry: ${CI_DOCKER_REGISTRY} and loading into local registry"
        echo "-----------------------";
        echo "";
        docker buildx build ${BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} -t ${IMAGE_NAME} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull --push --load ${CACHE_ARG} 
    else
        echo "buildx Creating Image: ${IMAGE_NAME} and loading into local registry"
        echo "-----------------------";
        docker buildx build ${BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} -t ${IMAGE_NAME} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull --load ${CACHE_ARG} 
    fi
  else
    if [ "$PUSH_IMAGES_TO_REGISTRY" = true ]; then
        echo "Creating Image: ${IMAGE_NAME} and publishing to registry: ${CI_DOCKER_REGISTRY}"
        echo "-----------------------";
        echo "";
        docker build ${BUILD_ARGS} -t ${IMAGE_NAME} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull --push ${CACHE_ARG} 
    else
        echo "Creating Image ${IMAGE_NAME} and loading into local registry"
        echo "-----------------------";
        echo "";
        docker build ${BUILD_ARGS} -t $IMAGE_NAME -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull ${CACHE_ARG} 
    fi
  fi

  if [ "${SHOW_DOCKER_HISTORY}" = true ]; then
    echo ""
    echo "---------------------------------"
    echo "Getting Docker History"
    echo "------"
    docker history $IMAGE_NAME
    echo "---------------------------------"
    echo ""
  fi
}
export -f build_image
