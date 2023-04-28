#syntax=docker/dockerfile:1.4
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
# https://hub.docker.com/_/debian?tab=tags&name=stable-slim

######################
# runtime image base
######################
FROM debian:stable-slim as runtime-base-image

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

USER root

SHELL ["/bin/bash", "-c"]

ARG BASE_LAYER_CACHE_KEY
ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF

  set -euo pipefail
  /mnt/shared/cmd/debian-install-os-updates.sh
  /mnt/shared/cmd/debian-install-support-tools.sh

  echo "#################################################"
  echo "Installing ca-certificates, tini..."
  echo "#################################################"
  apt-get install --no-install-recommends -y ca-certificates sudo tini

  echo "#################################################"
  echo "Adding [act] user..."
  echo "#################################################"
  addgroup --gid 1000 act
  adduser --uid 1000 --ingroup act --home /data --shell /bin/bash --disabled-password --gecos "" act
  adduser act sudo
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

  /mnt/shared/cmd/debian-cleanup.sh

EOF


######################
# build image
######################

# https://hub.docker.com/_/python?tab=tags&name=3-slim
FROM debian:stable-slim AS build-image

USER root

SHELL ["/bin/bash", "-c"]

ARG BASE_LAYER_CACHE_KEY
ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C
ARG INSTALL_SUPPORT_TOOLS=0

ARG ACT_RUNNER_DOWNLOAD_URL
ARG UPX_COMPRESS=true

RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF

  set -euo pipefail
  /mnt/shared/cmd/debian-install-os-updates.sh

  echo "#################################################"
  echo "Installing tools..."
  echo "#################################################"
  apt-get install --no-install-recommends -y binutils ca-certificates curl xz-utils

  if [[ $UPX_COMPRESS == "true" ]]; then
    echo "#################################################"
    echo "Downloading UPX..."
    echo "#################################################"
    mkdir /opt/upx
    upx_download_url=$(curl -fsSL https://api.github.com/repos/upx/upx/releases/latest | grep browser_download_url | grep amd64_linux.tar.xz | cut "-d\"" -f4)
    echo "Downloading [$upx_download_url]..."
    curl -fL $upx_download_url | tar Jxv -C /opt/upx --strip-components=1
    /opt/upx/upx --version
  fi

  echo "#################################################"
  echo "Downloading Gitea act runner..."
  echo "#################################################"
  curl -fsSL $ACT_RUNNER_DOWNLOAD_URL -o /usr/local/bin/act_runner
  chmod 755 /usr/local/bin/act_runner
  ls -l /usr/local/bin/act_runner
  echo "Stripping..."
  strip --strip-unneeded /usr/local/bin/act_runner
  ls -l /usr/local/bin/act_runner
  if [[ $UPX_COMPRESS == "true" ]]; then
    /opt/upx/upx -9 /usr/local/bin/act_runner
  fi
  act_runner --version

EOF


######################
# runtime image
######################
FROM runtime-base-image
COPY --from=build-image /usr/local/bin/act_runner /usr/local/bin/act_runner

ARG BUILD_DATE
ARG GIT_BRANCH
ARG GIT_COMMIT_HASH
ARG GIT_COMMIT_DATE
ARG GIT_REPO_URL

LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$GIT_COMMIT_HASH \
  org.label-schema.vcs-url=$GIT_REPO_URL

# Default configuration: can be overridden at the docker command line
ENV \
  INIT_SH_FILE='' \
  #
  GITEA_RUNNER_CONFIG_TEMPLATE_FILE='/opt/config.template.yaml' \
  #
  GITEA_RUNNER_NAME='' \
  GITEA_RUNNER_LABELS='' \
  GITEA_RUNNER_LABELS_DEFAULT='\
ubuntu-latest:docker://catthehacker/ubuntu:runner-22.04,\
ubuntu-22.04:docker://catthehacker/ubuntu:runner-22.04,\
ubuntu-20.04:docker://catthehacker/ubuntu:runner-20.04' \
  GITEA_RUNNER_UID=1000 \
  GITEA_RUNNER_GID=1000 \
  #
  GITEA_RUNNER_REGISTRATION_FILE='/data/.runner' \
  GITEA_RUNNER_REGISTRATION_TIMEOUT=30\
  GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=5s \
  #
  GITEA_RUNNER_LOG_LEVEL='info' \
  GITEA_RUNNER_MAX_PARALLEL_JOBS=1 \
  GITEA_RUNNER_JOB_TIMEOUT='3h' \
  GITEA_RUNNER_ENV_FILE='/data/.env' \
  GITEA_RUNNER_FETCH_TIMEOUT='5s' \
  GITEA_RUNNER_FETCH_INTERVAL='2s' \
  #
  GITEA_INSTANCE_INSECURE='false' \
  #
  GITEA_RUNNER_JOB_CONTAINER_NETWORK='bridge' \
  GITEA_RUNNER_JOB_CONTAINER_OPTIONS='' \
  GITEA_RUNNER_JOB_CONTAINER_PRIVILEGED='false' \
  GITEA_RUNNER_ACTION_CACHE_DIR='/data/cache/actions' \
  #
  ACT_CACHE_SERVER_ENABLED='true' \
  ACT_CACHE_SERVER_DIR='/data/cache/server' \
  ACT_CACHE_SERVER_HOST='' \
  ACT_CACHE_SERVER_PORT=0

RUN <<EOF

  set -euo pipefail

  echo "#################################################"
  echo "Writing build_info..."
  echo "#################################################"
  echo -e "
GIT_REPO:    $GIT_REPO_URL
GIT_BRANCH:  $GIT_BRANCH
GIT_COMMIT:  $GIT_COMMIT_HASH @ $GIT_COMMIT_DATE
IMAGE_BUILD: $BUILD_DATE" >/opt/build_info
  cat /opt/build_info

EOF

COPY image/*.sh /opt/
COPY image/config.template.yaml /opt/
COPY .shared/lib/bash-init.sh /opt/bash-init.sh

USER act

VOLUME [ "/data" ]

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/bin/bash", "/opt/run.sh"]
