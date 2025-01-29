#!/bin/bash
#
#
# Example usage to build the PHP 7.2 Apache images: ./run.sh -a php -m apache -v 7.2

set -a

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Include env if the file is found
if [ -f "${SCRIPTPATH}/.env" ]; then
  source ${SCRIPTPATH}/.env
fi

source "${SCRIPTPATH}/functions.sh"

IMAGE_TAG_SUFFIX="${IMAGE_TAG_SUFFIX:-}"
export IMAGE_TAG_SUFFIX;

USE_BUILDX="${USE_BUILDX:true}"
export USE_BUILDX;

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

PUSH_IMAGES_TO_REGISTRY=${PUSH_IMAGES_TO_REGISTRY:false}
export PUSH_IMAGES_TO_REGISTRY

PULL_IMAGES_FROM_REGISTRY=${PULL_IMAGES_FROM_REGISTRY:false}
export PULL_IMAGES_FROM_REGISTRY

USE_PLAIN_LOGS="${USE_PLAIN_LOGS:false}"
export USE_PLAIN_LOGS

SHOW_DOCKER_HISTORY="${SHOW_DOCKER_HISTORY:false}"
export SHOW_DOCKER_HISTORY


#Build Args
GIT_COMMIT=$(git log -1 --pretty=%h)
BUILD_TIMESTAMP=$( date '+%F_%H:%M:%S' )

# Build Common Build Args
COMMON_BUILD_ARGS="--build-arg BUILD_DATE=${BUILD_TIMESTAMP} --build-arg REVISION=${GIT_COMMIT}"


TARGET_APP="";
BUILD_SCRIPT="";
BUILD_FUNCTION="";

BUILD_EXTRA_MODULE="";
BUILD_EXTRA_VERSION="";

while getopts "ha:v:m:-:" OPT; do
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # Extract long option name
    OPTARG="${OPTARG#"$OPT"}" # Extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case $OPT in
    h | help)
      echo "TODO: Print help messages"
      fn_die;
    ;;
    a | application)
      fn_needs_arg;
      TARGET_APP="${OPTARG}"
      tmp_build_script_found=false
      tmp_build_script_fuc="build_app_${TARGET_APP}"

      if [  -f "${SCRIPTPATH}/${TARGET_APP}.sh" ]; then
        tmp_build_script_found=true
        BUILD_SCRIPT="${TARGET_APP}";
        BUILD_FUNCTION="";
      else
        if fn_exists "${tmp_build_script_fuc}"; then
          tmp_build_script_found=true
          BUILD_SCRIPT="";
          BUILD_FUNCTION="${tmp_build_script_fuc}"
        fi
      fi

      if [ "${tmp_build_script_found:false}" = false ]; then
        echo "Build script '${SCRIPTPATH}/${TARGET_APP}.sh' or function '${tmp_build_script_fuc}' NOT FOUND"
        exit 1
      fi
    ;;
    m | module)
      fn_needs_arg;
      BUILD_EXTRA_MODULE="${OPTARG}";
    ;;
    v | version)
      fn_needs_arg;
      BUILD_EXTRA_VERSION="${OPTARG}"
    ;;
    \? )           exit 2 ;;  # bad short option (error reported via getopts)
    * )            fn_die "Illegal option --$OPT" ;;

  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

if [ -z ${TARGET_APP+x} ] || [ -z "${TARGET_APP}" ]; then
  fn_die "Missing required option '-a'!";
fi

# This is a required argument, so if not set or empty, stop build.
if [ -z ${CI_DOCKER_NAMESPACE+x} ] || [ -z "${CI_DOCKER_NAMESPACE}" ]; then
    echo "Missing Docker Namespace!"
    exit 1
fi

# Check if in Dev Mode
if [ "$USE_BUILDX" = false ]; then
  echo "Buildx not enabled; fall back to the Docker build system."
else
  echo "Buildx enabled!"
fi

# Only need to log in if we are going to push or pull docker images from the registry.
if [ "${PUSH_IMAGES_TO_REGISTRY}" = true ] || [ "${PULL_IMAGES_FROM_REGISTRY}" = true ]; then
  # If we have Docker username and password login to Docker
  if [ "${CI_DOCKER_REGISTRY}" == "" ]; then
    docker_aws_login; #TODO ADD AWS LOGIN
    export PUSH_IMAGES_TO_REGISTRY=false
    export PULL_IMAGES_FROM_REGISTRY=false
  else
    if [ ! -z ${CI_DOCKER_USERNAME+x} ] && [ "${CI_DOCKER_USERNAME}" != "" ] && [ ! -z ${CI_DOCKER_TOKEN+x} ] && [ "${CI_DOCKER_TOKEN}" != "" ]; then
        echo "logging into registry ${CI_DOCKER_REGISTRY}"
        docker_hub_login "${CI_DOCKER_USERNAME}" "${CI_DOCKER_TOKEN}" "${CI_DOCKER_REGISTRY}"
    else
      export PUSH_IMAGES_TO_REGISTRY=false
      export PULL_IMAGES_FROM_REGISTRY=false
    fi
  fi
fi

DOCKER_BUILD_COMMAND="docker buildx build ${CI_BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS}";
if [ "$USE_BUILDX" = false ]; then
  # We are not using the buildx command, so we need to switch over to the basic Docker build command.
  DOCKER_BUILD_COMMAND="docker build ${CI_BUILD_ARGS}";
else
  docker buildx create --name base_img_builder --use
fi

if [ -n "${BUILD_SCRIPT}" ]; then
  echo ">>> Running build script '${BUILD_SCRIPT}.sh'";
  ${SCRIPTPATH}/${BUILD_SCRIPT}.sh "$@"
  ret_code=$?
elif [ -n "${BUILD_FUNCTION}" ]; then
  $BUILD_FUNCTION;
fi

if [ "$USE_BUILDX" = true ]; then
  if [ "$BUILD_DELETE_BUILDX_BUILDER_AFTER_BUILD" = true ]; then
      echo ">>> Removing base_img_builder"
      docker buildx rm base_img_builder
  fi
fi

# Only need to capture the return exit codes of build scripts if there is a build script used
if [ -n "${BUILD_SCRIPT}" ]; then
  exit $ret_code
fi