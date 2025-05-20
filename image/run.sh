#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner

# shellcheck disable=SC1091  # Not following: /opt/bash-init.sh was not specified as input
source /opt/bash-init.sh

#################################################################
# print header
#################################################################
if [[ ${1:-} == "" ]]; then
  cat <<'EOF'
   _____ _ _                            _     _____
  / ____(_) |                 /\       | |   |  __ \
 | |  __ _| |_ ___  __ _     /  \   ___| |_  | |__) |   _ _ __  _ __   ___ _ __
 | | |_ | | __/ _ \/ _` |   / /\ \ / __| __| |  _  / | | | '_ \| '_ \ / _ \ '__|
 | |__| | | ||  __/ (_| |  / ____ \ (__| |_  | | \ \ |_| | | | | | | |  __/ |
  \_____|_|\__\___|\__,_| /_/    \_\___|\__| |_|  \_\__,_|_| |_|_| |_|\___|_|
EOF

  cat /opt/build_info
  echo

  log INFO "$(act_runner --version)"
  log INFO "Timezone: $(date +"%Z %z")"
  log INFO "Hostname: $(hostname -f)"
  log INFO "IP Addresses: "
  awk '/32 host/ { if(uniq[ip]++ && ip != "127.0.0.1") print " - " ip } {ip=$2}' /proc/net/fib_trie
  log INFO "Config environment variables: "
  env | grep '^GITEA_\|^ACT_' | sort | sed 's/TOKEN=.*/TOKEN=******/g' | sed -e 's/^/ - /'
fi


#################################################################
# start docker daemon (if installed = DinD)
#################################################################
if [[ -f /usr/bin/dockerd-rootless.sh ]]; then
  export DOCKER_MODE=dind-rootless
  log INFO "Starting Docker engine (rootless)..."
  export DOCKER_HOST=unix://$HOME/.docker/run/docker.sock
  if [[ ! -f "$HOME/.config/docker/daemon.json" ]]; then
    # workaround for "Not using native diff for overlay2, this may cause degraded performance for building images: running in a user namespace  storage-driver=overlay2"
    mkdir -p "$HOME/.config/docker"
    echo '{"storage-driver":"fuse-overlayfs"}' > "$HOME/.config/docker/daemon.json"
  fi

  export container=docker # from dind-hack
  export XDG_RUNTIME_DIR=$HOME/.docker/run
  mkdir -p "$XDG_RUNTIME_DIR"
  rm -f "$XDG_RUNTIME_DIR/docker.pid" "$XDG_RUNTIME_DIR/docker/containerd/containerd.pid"
  /usr/bin/dockerd-rootless.sh -p "$HOME/.docker/run/docker.pid" > "$HOME/.docker/docker.log" 2>&1 &
  export DOCKER_PID=$!
  while ! docker stats --no-stream &>/dev/null; do
    log INFO "Waiting for Docker engine to start..."
    sleep 2
    tail -n 1 /data/.docker/docker.log
  done
  echo "==========================================================="
  docker info
  echo "==========================================================="
elif [[ -f /usr/bin/dockerd ]]; then
  export DOCKER_MODE=dind
  log INFO "Starting Docker engine..."
  sudo rm -f /var/run/docker.pid /run/docker/containerd/containerd.pid
  sudo /usr/local/bin/dind-hack true
  sudo service docker start
  while ! docker stats --no-stream &>/dev/null; do
    log INFO "Waiting for Docker engine to start..."
    sleep 2
    tail -n 1 /var/log/docker.log
  done
  # shellcheck disable=SC2155  # Declare and assign separately to avoid masking return values
  export DOCKER_PID=$(</var/run/docker.pid)
  echo "==========================================================="
  docker info
  echo "==========================================================="
else
  export DOCKER_MODE=dood
fi

if [[ -z ${GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST:-} ]]; then
  export GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST=${DOCKER_HOST:-unix:///var/run/docker.sock}
fi


#################################################################
# check if act user UID/GID needs adjustment
#################################################################
fix_permissions=false
if [[ -n ${GITEA_RUNNER_UID:-} ]]; then
  effective_uid=$(id -u act)
  if [[ $GITEA_RUNNER_UID != "$effective_uid" ]]; then
    fix_permissions=true
  fi
fi

if [[ -n ${GITEA_RUNNER_GID:-} ]]; then
  effective_gid=$(id -g act)
  if [[ $GITEA_RUNNER_GID != "$effective_gid" ]]; then
    fix_permissions=true
  fi
fi


#################################################################
# check if act user has read/write access to docker socket in GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST
#################################################################
if [[ $DOCKER_MODE != "dind-rootless" ]]; then
  if [[ $GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST == unix://* ]]; then
    docker_sock=${GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST#unix://}
    if [[ ! -w $docker_sock || ! -r $docker_sock ]]; then
      docker_group=$(stat -c '%G' "$docker_sock")
      if [[ $docker_group == "UNKNOWN" ]]; then
        docker_gid=$(stat -c '%g' "$docker_sock")
        docker_group="docker$docker_gid"
        fix_permissions=true
      fi

      if ! id -nG act | grep -qw "$docker_group"; then
        fix_permissions=true
      fi
    fi
  fi
fi


#################################################################
# adjust act user UID/GID if required
#################################################################
if [[ $fix_permissions == "true" ]]; then
  log INFO "Fixing permissions..."
  exec sudo -E bash /opt/fix_permissions.sh
else
  exec bash /opt/run_runner.sh
fi
