#syntax=docker/dockerfile:1.4
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#user-content-syntax
# see https://docs.docker.com/build/dockerfile/frontend/
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
# https://hub.docker.com/_/debian?tab=tags&name=stable-slim

FROM debian:stable-slim

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

USER root

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

ARG INSTALL_SUPPORT_TOOLS=0

ARG UPX_COMPRESS=true

ARG BASE_LAYER_CACHE_KEY

# dood|dind|dind-rootless
ARG FLAVOR
ARG GITEA_ACT_RUNNER_VERSION

RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF

  /mnt/shared/cmd/debian-install-os-updates.sh
  /mnt/shared/cmd/debian-install-support-tools.sh

  function minimize() {
    ls -l "$@"
    echo "Stripping [$*]..."
    command strip --strip-unneeded "$@"
    ls -l "$@"
    if [[ $UPX_COMPRESS == "true" ]]; then
      echo "Compressing [$*]..."
      /opt/upx/upx -9 "$@" || true
    fi
  }

  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)
  case $arch in
    armhf) arch=arm-7 ;;
    amd64|arm64) ;;
    *) echo "Unsupported arch: $arch"; exit 1;;
  esac

  echo "#################################################"
  echo "Installing required packages..."
  echo "#################################################"
  apt-get install --no-install-recommends -y binutils ca-certificates curl sudo tini

  if [[ $UPX_COMPRESS == "true" ]]; then
    echo "#################################################"
    echo "Downloading UPX..."
    echo "#################################################"
    apt-get install --no-install-recommends -y xz-utils
    mkdir /opt/upx
    upx_download_url=$(curl "https://api.github.com/repos/upx/upx/releases/latest" | grep browser_download_url | grep ${arch}_linux.tar.xz | cut "-d\"" -f4)
    echo "Downloading [$upx_download_url]..."
    curl "$upx_download_url" | tar Jxv -C /opt/upx --strip-components=1
    /opt/upx/upx --version
  fi

  minimize /usr/bin/tini-static

  echo "#################################################"
  echo "Downloading Gitea act runner..."
  echo "#################################################"
  if [[ $GITEA_ACT_RUNNER_VERSION == "nightly" ]]; then
    act_runner_download_url=https://dl.gitea.com/act_runner/nightly/act_runner-${GITEA_ACT_RUNNER_VERSION}-linux-${arch}
  else
    act_runner_download_url=https://gitea.com/gitea/act_runner/releases/download/v${GITEA_ACT_RUNNER_VERSION}/act_runner-${GITEA_ACT_RUNNER_VERSION}-linux-${arch}
  fi
  echo "Downloading [$act_runner_download_url]..."
  curl "$act_runner_download_url" -o /usr/local/bin/act_runner
  chmod 755 /usr/local/bin/act_runner
  minimize /usr/local/bin/act_runner
  act_runner --version

  echo "#################################################"
  echo "Adding [act] user..."
  echo "#################################################"
  addgroup --gid 1000 act
  adduser --uid 1000 --ingroup act --home /data --shell /bin/bash --disabled-password --gecos "" act
  adduser act users
  adduser act sudo
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

  if [[ $FLAVOR == dind* ]]; then
    echo "#################################################"
    echo "Installing docker engine..."
    echo "#################################################"
    # https://docs.docker.com/engine/install/debian/#install-using-the-repository
    apt-get install --no-install-recommends -y gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl "https://download.docker.com/linux/debian/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      "$(source /etc/os-release && echo "$VERSION_CODENAME")" stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    (set -x; apt-get install --no-install-recommends -y docker-ce containerd.io fuse-overlayfs)
    apt-get remove -y gnupg
    apt-get autoremove -y

    minimize /usr/bin/containerd* /usr/bin/ctr /usr/bin/docker* /usr/bin/runc

    docker --version
    runc --version

    # https://github.com/docker/for-linux/issues/1437#issuecomment-1293818806
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

    # set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    addgroup --system dockremap
    adduser --system --ingroup dockremap dockremap
    echo 'dockremap:165536:65536' | tee -a /etc/subuid
    echo 'dockremap:165536:65536' | tee -a /etc/subgid

    if [[ $FLAVOR == dind-rootless ]]; then
      # https://docs.docker.com/engine/security/rootless/
      (set -x; apt-get install --no-install-recommends -y \
        dbus-user-session \
        `# docker-ce-rootless-extras` \
        kmod \
        iproute2 \
        slirp4netns \
        uidmap)

      # workaround for "[rootlesskit:parent] error: failed to start the child: fork/exec /proc/self/exe: operation not permitted"
      # see https://github.com/rootless-containers/rootlesskit/issues/425
      (set -x; apt-get install --no-install-recommends -y docker-ce-rootless-extras=5:25.0.3-1~debian.12~bookworm --allow-downgrades)

      (set -x; rootlesskit --version)
      (set -x; runuser -u act -g act -- /usr/bin/dockerd-rootless-setuptool.sh install --skip-iptables)

      # workaround "failed to load plugin io.containerd.internal.v1.opt  error="mkdir /opt/containerd: permission denied"
      mkdir /opt/containerd
      chown act:act /opt/containerd
    else
      docker_version=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
      curl "https://raw.githubusercontent.com/moby/moby/v${docker_version}/hack/dind" -o /usr/local/bin/dind-hack
      chmod +x /usr/local/bin/dind-hack
      usermod -aG docker act
    fi
  fi

  echo "#################################################"
  echo "Cleanup..."
  echo "#################################################"
  apt-get remove -y binutils curl
  rm -rf /opt/upx
  /mnt/shared/cmd/debian-cleanup.sh

EOF

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
ubuntu-latest:docker://catthehacker/ubuntu:act-22.04,\
ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04,\
ubuntu-20.04:docker://catthehacker/ubuntu:act-20.04' \
  GITEA_RUNNER_UID=1000 \
  GITEA_RUNNER_GID=1000 \
  #
  GITEA_RUNNER_REGISTRATION_TIMEOUT=30\
  GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=5s

RUN <<EOF

  echo "#################################################"
  echo "Writing build_info..."
  echo "#################################################"
  echo "
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

VOLUME /data

# only for dind relevant
VOLUME /var/lib/docker

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/bin/bash", "/opt/run.sh"]
