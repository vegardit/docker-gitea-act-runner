#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner

function curl() {
  command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
}

shared_lib="$(dirname $0)/.shared"
[ -e "$shared_lib" ] || curl https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=$(date +%s) | bash -s v1 "$shared_lib" || exit 1
source "$shared_lib/lib/build-image-init.sh"


#################################################
# check prereqs
#################################################

if [[ "${DOCKER_PUSH:-}" == "true" ]]; then
  if ! hash regctl &>/dev/null; then
    log ERROR "regctl (aka regclient) command line tool is misssing!"
  fi
fi


#################################################
# specify target docker registry/repo
#################################################
gitea_act_runner_version=${GITEA_ACT_RUNNER_VERSION:-latest}
image_repo=${DOCKER_IMAGE_REPO:-vegardit/gitea-act-runner}


#################################################
# resolve gitea act runner version
#################################################
case $gitea_act_runner_version in
  latest) gitea_act_runner_effective_version=$(curl https://gitea.com/gitea/act_runner/releases.rss | grep -oP "releases/tag/v\K\d\.\d\.\d\d?" | head -n 1)
          ;;
  *)      gitea_act_runner_effective_version=$gitea_act_runner_version
          ;;
esac
image_name=$image_repo:${DOCKER_IMAGE_TAG_PREFIX:-}$gitea_act_runner_version
image_name2=$image_repo:${DOCKER_IMAGE_TAG_PREFIX:-}$gitea_act_runner_effective_version


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
docker run --privileged --rm tonistiigi/binfmt --install all
export DOCKER_BUILD_KIT=1
export DOCKER_CLI_EXPERIMENTAL=1 # prevents "docker: 'buildx' is not a docker command."
docker buildx version # ensures buildx is enabled
docker buildx create --use # prevents: error: multiple platforms feature is currently not supported for docker driver. Please switch to a different driver (eg. "docker buildx create --use")
docker buildx build "$project_root" \
  --file "image/Dockerfile" \
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
  --build-arg GITEA_ACT_RUNNER_VERSION="$gitea_act_runner_effective_version" \
  --build-arg FLAVOR=$DOCKER_IMAGE_FLAVOR \
  $(if [[ "${ACT:-}" == "true" || "${DOCKER_PUSH:-}" != "true" ]]; then \
    echo -n "--load --output type=docker"; \
  else \
    echo -n "--platform linux/amd64,linux/arm64,linux/arm/v7"; \
  fi) \
  -t $image_name \
  -t $image_name2 \
  $(if [[ "${DOCKER_PUSH:-}" == "true" ]]; then echo -n "--push"; fi) \
  "$@"
docker buildx stop
set +x

if [[ "${DOCKER_PUSH:-}" == "true" ]]; then
  docker image pull $image_name
fi

#################################################
# push image to ghcr.io
#################################################
if [[ "${DOCKER_PUSH_GHCR:-}" == "true" ]]; then
  (set -x; regctl image copy $image_name ghcr.io/$image_name)
  (set -x; regctl image copy $image_name2 ghcr.io/$image_name2)
fi


#################################################
# test image
#################################################
echo
log INFO "Testing docker image [$image_name]..."
(set -x; docker run --rm $image_name act_runner --version)
echo


#################################################
# perform security audit
#################################################
# TODO see https://gitea.com/gitea/act_runner/issues/513
if [[ "${DOCKER_AUDIT_IMAGE:-1}" == 1 && "$GITEA_ACT_RUNNER_VERSION" == "nightly" ]]; then
  bash "$shared_lib/cmd/audit-image.sh" $image_name
fi
