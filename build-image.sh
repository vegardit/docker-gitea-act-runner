#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner

shared_lib="$(dirname $0)/.shared"
[ -e "$shared_lib" ] || curl -sSf https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=$(date +%s) | bash -s v1 "$shared_lib" || exit 1
source "$shared_lib/lib/build-image-init.sh"


#################################################
# specify target docker registry/repo
#################################################
docker_registry=${DOCKER_REGISTRY:-docker.io}
image_repo=${DOCKER_IMAGE_REPO:-vegardit/gitea-act-runner}
image_name=$image_repo:${DOCKER_IMAGE_TAG:-latest}


#################################################
# build the image
#################################################
log INFO "Building docker image [$image_name]..."
if [[ $OSTYPE == "cygwin" || $OSTYPE == "msys" ]]; then
   project_root=$(cygpath -w "$project_root")
fi

# https://github.com/docker/buildx/#building-multi-platform-images
docker run --privileged --rm tonistiigi/binfmt --install all
export DOCKER_CLI_EXPERIMENTAL=enabled # prevents "docker: 'buildx' is not a docker command."
docker buildx create --use # prevents: error: multiple platforms feature is currently not supported for docker driver. Please switch to a different driver (eg. "docker buildx create --use")
docker buildx build "$project_root" \
   --file "image/$DOCKER_FILE" \
   --progress=plain \
   --pull \
   --build-arg INSTALL_SUPPORT_TOOLS=${INSTALL_SUPPORT_TOOLS:-0} \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY=$base_layer_cache_key \
   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d @$(git log -1 --format='%at') --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   --platform linux/amd64,linux/arm64,linux/arm/v7 \
   -t $image_name \
   $(if [[ "${DOCKER_PUSH:-0}" == "true" ]]; then echo -n "--push"; fi) \
   "$@"
docker buildx stop
docker image pull $image_name


#################################################
# test image
#################################################
echo
log INFO "Testing docker image [$image_name]..."
docker run --rm $image_name act_runner --version
echo


#################################################
# perform security audit
#################################################
if [[ "${DOCKER_AUDIT_IMAGE:-1}" == 1 ]]; then
   bash "$shared_lib/cmd/audit-image.sh" $image_name
fi
