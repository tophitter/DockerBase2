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

# Generate BUILD_ID based on git state and overrides
function get_build_id() {
    # Priority 1: Manual override
    if [[ -n "${BUILD_ID_OVERRIDE:-}" ]]; then
        echo "${BUILD_ID_OVERRIDE}"
        return
    fi
    
    # Priority 2: Git tag (production build)
    local git_tag=$(git describe --exact-match --tags HEAD 2>/dev/null)
    if [[ -n "$git_tag" ]]; then
        echo "$git_tag"
        return
    fi
    
    # Priority 3: Git hash (development build)
    echo "g${GIT_COMMIT}"
}
export -f get_build_id

# Load additional tags for an image from mapping files
function get_additional_tags() {
    local image_name=$1
    local mapping_file="${SCRIPTPATH}/mappings/${image_name}.mapping"
    
    # Check if mapping file exists
    if [[ -f "$mapping_file" ]]; then
        # Read file and return tags (substitute BUILD_ID)
        local build_id=$(get_build_id)
        while IFS= read -r tag_template || [[ -n "$tag_template" ]]; do
            # Skip empty lines and comments
            [[ -z "$tag_template" || "$tag_template" =~ ^[[:space:]]*# ]] && continue
            # Substitute {{BUILD_ID}} in template (changed from ${BUILD_ID})
            echo "${tag_template//\{\{BUILD_ID\}\}/$build_id}"
        done < "$mapping_file"
    fi
}
export -f get_additional_tags

# Check if image has additional tag mappings
function has_additional_mappings() {
    local image_name=$1
    [[ -f "${SCRIPTPATH}/mappings/${image_name}.mapping" ]]
}
export -f has_additional_mappings

# Extract PHP version from image name (e.g., "php7.2-apache" -> "7.2")
function extract_php_version() {
    local image_name=$1
    if [[ "$image_name" =~ php([0-9]+\.[0-9]+)-(apache|build) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}
export -f extract_php_version

# Check if build should get latest tags (production builds only)
function should_apply_latest_tags() {
    local build_id=$1
    
    # Only apply latest tags for production builds (not starting with 'g')
    if [[ ! "$build_id" =~ ^g[0-9a-f]+ ]]; then
        return 0  # true - is production build
    else
        return 1  # false - is dev build
    fi
}
export -f should_apply_latest_tags

# Validate that legacy-web is only used in one mapping file
function validate_legacy_web_usage() {
    local legacy_count=0
    local legacy_file=""
    
    for mapping_file in "${SCRIPTPATH}/mappings"/*.mapping; do
        [[ -f "$mapping_file" ]] || continue
        if grep -q "legacy-web:" "$mapping_file"; then
            ((legacy_count++))
            legacy_file=$(basename "$mapping_file")
        fi
    done
    
    if [[ $legacy_count -gt 1 ]]; then
        echo "ERROR: legacy-web tag found in multiple mapping files. Should only be in one file (symlink behavior)."
        return 1
    elif [[ $legacy_count -eq 1 ]]; then
        echo "INFO: legacy-web tag found in: $legacy_file"
    fi
    
    return 0
}
export -f validate_legacy_web_usage

# Check if old tags should be disabled for this image
function should_disable_old_tags() {
    local image_path=$1
    
    # Only check if new tagging is enabled
    if [[ "${ENABLE_NEW_TAGGING:-true}" != "true" ]]; then
        return 1  # false - don't disable old tags when new tagging is off
    fi

    # Check for .disable-old-tags file in the build path
    if [[ -f "${SCRIPTPATH}/../${image_path}/.disable-old-tags" ]]; then
        return 0  # true - disable old tags
    else
        return 1  # false - keep old tags
    fi
}
export -f should_disable_old_tags

# Build Docker image pass in arguments: image_name, image_tag, path_to_docker_file
function build_image(){
  tName=$1
  tTag=$2
  tPath=$3

  REPO="${CI_DOCKER_NAMESPACE}/${tName}"
  TAG="${tTag}${IMAGE_TAG_SUFFIX}"
  CACHE_ARG="";

  # Legacy custom tag handling - can be removed later
  if [ "${tName}" == "php7.2-apache" ]; then
    echo "DO Custom Tags"
  fi

  IMAGE_NAME="${REPO}:${TAG}"

  EFFECTIVE_BUILD_VERSION="${TAG}"
  if [[ "${ENABLE_NEW_TAGGING:-true}" == "true" ]] && has_additional_mappings "$tName"; then
      EFFECTIVE_BUILD_VERSION=$(get_build_id)
      echo "Using BUILD_VERSION: ${EFFECTIVE_BUILD_VERSION} (from BUILD_ID)"
  else
      echo "Using BUILD_VERSION: ${EFFECTIVE_BUILD_VERSION} (from TAG)"
  fi

  IMAGE_TITLE="${CI_DOCKER_NAMESPACE}/${tName}"
  IMAGE_DESC="Docker image for ${tName}"

  BUILD_ARGS="${CI_BUILD_ARGS} ${COMMON_BUILD_ARGS} --build-arg BUILD_VERSION=${EFFECTIVE_BUILD_VERSION}"

  # Define image metadata based on the primary image name
  case "$tName" in
      php*-apache)
        PHP_VER=$(extract_php_version "$tName")
        IMAGE_TITLE="PHP ${PHP_VER} Web Server"
        IMAGE_DESC="Production-ready PHP ${PHP_VER} Apache environment"
        ;;
    php*-build)
        PHP_VER=$(extract_php_version "$tName")
        IMAGE_TITLE="PHP ${PHP_VER} Development Environment"
        IMAGE_DESC="PHP ${PHP_VER} with build tools, composer, and development utilities"
        ;;
  esac
  BUILD_ARGS="${BUILD_ARGS} --build-arg IMAGE_TITLE=${IMAGE_TITLE// /_} --build-arg IMAGE_DESC=${IMAGE_DESC// /_}"

  # if plain logging is enabled then add --progress plain as a build arg
  if [ "$USE_PLAIN_LOGS" = true ]; then
    BUILD_ARGS=" ${BUILD_ARGS} --progress plain"
  fi

  if [ "${PULL_IMAGES_FROM_REGISTRY}" = true ]; then
    # Determine which image to use for cache
    CACHE_IMAGE=""
    
    if should_disable_old_tags "$tPath" && [[ "${ENABLE_NEW_TAGGING:-true}" == "true" ]] && has_additional_mappings "$tName"; then
        # Old tags disabled - try to cache from new image name
        BUILD_ID=$(get_build_id)
        NEW_TAGS=$(get_additional_tags "$tName")
        FIRST_NEW_TAG=$(echo "$NEW_TAGS" | head -n1)
        if [[ -n "$FIRST_NEW_TAG" ]]; then
            CACHE_IMAGE="${CI_DOCKER_NAMESPACE}/${FIRST_NEW_TAG}"
            echo "Old tags disabled - attempting cache from new image: ${CACHE_IMAGE}"
        fi
    else
        # Use old image for cache (current behavior)  
        CACHE_IMAGE="${IMAGE_NAME}"
        echo "Using cache from original image: ${CACHE_IMAGE}"
    fi
    
    if [[ -n "$CACHE_IMAGE" ]]; then
        CACHE_ARG="--cache-from ${CACHE_IMAGE}"
        CACHE_REPO=$(echo "$CACHE_IMAGE" | cut -d':' -f1)
        CACHE_TAG=$(echo "$CACHE_IMAGE" | cut -d':' -f2)
        
        echo "Pull Latest version of ${CACHE_IMAGE} from registry if found"
        if docker_tag_exists "$CACHE_REPO" "$CACHE_TAG"; then
            docker pull "${CACHE_IMAGE}"
        else
            echo ""
            echo "${CACHE_IMAGE} not found in registry no cache will be used"
            CACHE_ARG=""
        fi
    else
        echo "No suitable cache image found"
        CACHE_ARG=""
    fi
  else
      echo "Cache Not Enabled, Skipping pulling image from registry"
  fi

  #Send empty echo to make a new line in the output
  echo "";

  # Collect all tags for this build
  ALL_TAGS=""

  # Add original tag unless disabled
  if should_disable_old_tags "$tPath"; then
      echo "Old tags disabled for ${tName} (found .disable-old-tags file)"
  else
      ALL_TAGS="-t ${IMAGE_NAME}"
  fi
  
  # Check for additional mappings
  if [[ "${ENABLE_NEW_TAGGING:-true}" == "true" ]] && has_additional_mappings "$tName"; then
    echo "Found additional mappings for ${tName}"

    # Validate legacy-web usage (only run for images with mappings)
    if ! validate_legacy_web_usage; then
      echo "ERROR: Validation failed! Build stopped."
      exit 1
    fi

    BUILD_ID=$(get_build_id)
    echo "Using BUILD_ID: ${BUILD_ID}"

    # Get additional tags and add them to the build
    while IFS= read -r additional_tag; do
      [[ -z "$additional_tag" ]] && continue
      FULL_ADDITIONAL_TAG="${CI_DOCKER_NAMESPACE}/${additional_tag}"
      ALL_TAGS="${ALL_TAGS} -t ${FULL_ADDITIONAL_TAG}"
      echo "  -> Additional tag: ${FULL_ADDITIONAL_TAG}"
    done < <(get_additional_tags "$tName")
    
    # Add latest tags for production builds
    if should_apply_latest_tags "$BUILD_ID"; then
      echo "Production build detected - adding latest tags"
      PHP_VERSION=$(extract_php_version "$tName")
      
      if [[ -n "$PHP_VERSION" ]]; then
         if [[ "$tName" =~ apache$ ]]; then
          ALL_TAGS="${ALL_TAGS} -t ${CI_DOCKER_NAMESPACE}/php-base:latest-p${PHP_VERSION}-apache"
          echo "  -> Latest tag: ${CI_DOCKER_NAMESPACE}/php-base:latest-p${PHP_VERSION}-apache"
        elif [[ "$tName" =~ build$ ]]; then
          ALL_TAGS="${ALL_TAGS} -t ${CI_DOCKER_NAMESPACE}/php-base:latest-p${PHP_VERSION}-devel"
          echo "  -> Latest tag: ${CI_DOCKER_NAMESPACE}/php-base:latest-p${PHP_VERSION}-devel"
        fi
        
        # Legacy-web latest tag (only for PHP 7.2 apache)
        if [[ "$tName" == "php7.2-apache" ]]; then
          ALL_TAGS="${ALL_TAGS} -t ${CI_DOCKER_NAMESPACE}/legacy-web:latest"
          echo "  -> Legacy latest: ${CI_DOCKER_NAMESPACE}/legacy-web:latest"
        fi
      fi
    else
      echo "Development build detected - no latest tags"
    fi
  fi

  # Ensure we have at least one tag
  if [[ -z "$ALL_TAGS" ]]; then
      echo "ERROR: No tags to build! Either enable old tags or ensure new tagging mappings exist."
      exit 1
  fi

  echo "";
  echo "Building with tags: ${ALL_TAGS}"
  echo "";
  # Build the image with all tags
  if [ "${USE_BUILDX}" = true ]; then
    if [ "${PUSH_IMAGES_TO_REGISTRY}" = true ]; then
        echo "buildx Creating Image with all tags and publishing to registry: ${CI_DOCKER_REGISTRY}"
        echo "-----------------------";
        echo "";
        docker buildx build ${BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} ${ALL_TAGS} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull --push --load ${CACHE_ARG} 
    else
        echo "buildx Creating Image with all tags and loading into local registry"
        echo "-----------------------";
        docker buildx build ${BUILD_ARGS} --platform=${CI_BUILD_PLATFORMS} ${ALL_TAGS} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull --load ${CACHE_ARG} 
    fi
  else
    if [ "$PUSH_IMAGES_TO_REGISTRY" = true ]; then
        echo "Creating Image with all tags and publishing to registry: ${CI_DOCKER_REGISTRY}"
        echo "-----------------------";
        echo "";
        docker build ${BUILD_ARGS} ${ALL_TAGS} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull ${CACHE_ARG} 
        # Push all tags individually (non-buildx doesn't support --push with multiple repos)
        echo "Pushing individual tags..."
        echo "${ALL_TAGS}" | grep -o '\-t [^[:space:]]*' | sed 's/-t //' | while read -r tag; do
          echo "Pushing: ${tag}"
          docker push "${tag}"
        done
    else
        echo "Creating Image with all tags and loading into local registry"
        echo "-----------------------";
        echo "";
        docker build ${BUILD_ARGS} ${ALL_TAGS} -f ${SCRIPTPATH}/../${tPath}/Dockerfile ${SCRIPTPATH}/../${tPath} --pull ${CACHE_ARG} 
    fi
  fi

  if [ "${SHOW_DOCKER_HISTORY}" = true ]; then
    # Determine which image to show history for
    HISTORY_IMAGE=""
    
    if should_disable_old_tags "$tPath" && [[ "${ENABLE_NEW_TAGGING:-true}" == "true" ]] && has_additional_mappings "$tName"; then
        # Old tags disabled - show history from first new image
        BUILD_ID=$(get_build_id)
        NEW_TAGS=$(get_additional_tags "$tName")
        FIRST_NEW_TAG=$(echo "$NEW_TAGS" | head -n1)
        if [[ -n "$FIRST_NEW_TAG" ]]; then
            HISTORY_IMAGE="${CI_DOCKER_NAMESPACE}/${FIRST_NEW_TAG}"
        fi
    else
        # Use original image (current behavior)
        HISTORY_IMAGE="${IMAGE_NAME}"
    fi
    
    if [[ -n "$HISTORY_IMAGE" ]]; then
        echo ""
        echo "---------------------------------"
        echo "Getting Docker History for ${HISTORY_IMAGE}"
        echo "------"
        docker history "$HISTORY_IMAGE"
        echo "---------------------------------"
        echo ""
    fi
  fi

  # Summary of pushed images
  if [ "${PUSH_IMAGES_TO_REGISTRY}" = true ]; then
      echo ""
      echo "========================================="
      echo "PUSHED IMAGES SUMMARY:"
      echo "========================================="
      
      # Extract and display all tags that were pushed
      echo "${ALL_TAGS}" | grep -o '\-t [^[:space:]]*' | sed 's/-t //' | while read -r tag; do
          echo "✓ ${tag}"
      done
      
      echo "========================================="
      echo ""
  else
      echo ""
      echo "========================================="
      echo "BUILT IMAGES SUMMARY (Local Only):"
      echo "========================================="
      
      # Show what was built locally
      echo "${ALL_TAGS}" | grep -o '\-t [^[:space:]]*' | sed 's/-t //' | while read -r tag; do
          echo "✓ ${tag}"
      done
      
      echo "========================================="
      echo ""
  fi
}
export -f build_image
