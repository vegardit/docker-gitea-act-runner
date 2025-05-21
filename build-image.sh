#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner

function curl() {
   command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
}

shared_lib="$(dirname "${BASH_SOURCE[0]}")/.shared"
[[ -e $shared_lib ]] || curl "https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=$(date +%s)" | bash -s v1 "$shared_lib" || exit 1
# shellcheck disable=SC1091  # Not following: $shared_lib/lib/build-image-init.sh was not specified as input
source "$shared_lib/lib/build-image-init.sh"


#################################################
# specify target image repo/tag
#################################################
gitea_act_runner_version=${GITEA_ACT_RUNNER_VERSION:-latest}
base_image_name=${DOCKER_BASE_IMAGE:-debian:stable-slim}
image_repo=${DOCKER_IMAGE_REPO:-vegardit/gitea-act-runner}


#################################################
# resolve gitea act runner version
#################################################
case $gitea_act_runner_version in
   latest) gitea_act_runner_effective_version=$(curl https://gitea.com/gitea/act_runner/releases.rss | grep -oP "releases/tag/v\K\d\.\d\.\d\d?" | head -n 1) ;;
   *)      gitea_act_runner_effective_version=$gitea_act_runner_version ;;
esac


#################################################
# calculate tags
#################################################
declare -a tags=()
tags+=("$image_repo:${DOCKER_IMAGE_TAG_PREFIX:-}$gitea_act_runner_version")
tags+=("$image_repo:${DOCKER_IMAGE_TAG_PREFIX:-}$gitea_act_runner_effective_version")

tag_args=()
for t in "${tags[@]}"; do
  tag_args+=( --tag "$t" )
done

image_name=${tags[0]}


#################################################
# build the image
#################################################
log INFO "Building docker image [$image_name]..."
if [[ $OSTYPE == "cygwin" || $OSTYPE == "msys" ]]; then
   project_root=$(cygpath -w "$project_root")
fi

# https://github.com/docker/buildx/#building-multi-platform-images
set -x

docker --version
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=1 # prevents "docker: 'buildx' is not a docker command."

# Register QEMU emulators for all architectures so Docker can run and build multi-arch images
docker run --privileged --rm ghcr.io/dockerhub-mirror/tonistiigi__binfmt --install all

# https://docs.docker.com/build/buildkit/configure/#resource-limiting
echo "
[worker.oci]
  max-parallelism = 3
" | sudo tee /etc/buildkitd.toml

docker buildx version # ensures buildx is enabled
docker buildx create --config /etc/buildkitd.toml --use # prevents: error: multiple platforms feature is currently not supported for docker driver. Please switch to a different driver (eg. "docker buildx create --use")
trap 'docker buildx stop' EXIT
# shellcheck disable=SC2154,SC2046  # base_layer_cache_key is referenced but not assigned / Quote this to prevent word splitting
docker buildx build "$project_root" \
   --file "image/Dockerfile" \
   --progress=plain \
   --pull \
   --build-arg INSTALL_SUPPORT_TOOLS="${INSTALL_SUPPORT_TOOLS:-0}" \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY="$base_layer_cache_key" \
   --build-arg BASE_IMAGE="$base_image_name" \
   --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d "@$(git log -1 --format='%at')" --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   --build-arg GITEA_ACT_RUNNER_VERSION="$gitea_act_runner_effective_version" \
   --build-arg FLAVOR="$DOCKER_IMAGE_FLAVOR" \
   $(if [[ ${ACT:-} == "true" || ${DOCKER_PUSH:-} != "true" ]]; then \
      echo -n "--load --output type=docker"; \
   else \
      echo -n "--platform linux/amd64,linux/arm64,linux/arm/v7"; \
   fi) \
   "${tag_args[@]}" \
   $(if [[ ${DOCKER_PUSH:-} == "true" ]]; then echo -n "--push"; fi) \
   "$@"
set +x

if [[ ${DOCKER_PUSH:-} == "true" ]]; then
   docker image pull "$image_name"
fi


#################################################
# test image
#################################################
echo
log INFO "Testing docker image [$image_name]..."
(set -x; docker run --rm "$image_name" act_runner --version)
echo


#################################################
# perform security audit
#################################################
# TODO see https://gitea.com/gitea/act_runner/issues/513
if [[ ${DOCKER_AUDIT_IMAGE:-1} == "1" && $GITEA_ACT_RUNNER_VERSION == "nightly" ]]; then
   bash "$shared_lib/cmd/audit-image.sh" "$image_name"
fi


#################################################
# push image to ghcr.io
#################################################
if [[ ${DOCKER_PUSH_GHCR:-} == "true" ]]; then
   for tag in "${tags[@]}"; do
      set -x
      docker run --rm \
         -u "$(id -u):$(id -g)" -e HOME -v "$HOME:$HOME" \
         -v /etc/docker/certs.d:/etc/docker/certs.d:ro \
         ghcr.io/regclient/regctl:latest \
         image copy "$tag" "ghcr.io/$tag"
      set +x
   done
fi
