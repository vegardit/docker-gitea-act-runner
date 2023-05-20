#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
source /opt/bash-init.sh

#################################################################
# Adjust UID/GID and file permissions based on env var config
#################################################################
if [ -n "${GITEA_RUNNER_UID:-}" ]; then
  effective_uid=$(id -u act)
  if [ "$GITEA_RUNNER_UID" != "$effective_uid" ]; then
    log INFO "Changing UID of user [act] from $effective_uid to $GITEA_RUNNER_UID..."
    usermod -o -u "$GITEA_RUNNER_UID" act
  fi
fi

if [ -n "${GITEA_RUNNER_GID:-}" ]; then
  effective_gid=$(id -g act)
  if [ "$GITEA_RUNNER_GID" != "$effective_gid" ]; then
    log INFO "Changing GID of user [act] from $effective_gid to $GITEA_RUNNER_GID..."
    groupmod -o -g "$GITEA_RUNNER_GID" act
  fi
fi
chown -R act:act /data

if [[ -f /usr/bin/dockerd ]]; then
  log INFO "Starting docker engine..."
  service docker start
  while [[ ! -e /var/run/docker.sock ]]; do sleep 2; done
fi

docker_group=$(stat -c '%G' /var/run/docker.sock)
if [[ $docker_group == "UNKNOWN" ]]; then
  docker_gid=$(stat -c '%g' /var/run/docker.sock)
  docker_group="docker$docker_gid"
  log INFO "Creating group [$docker_group]..."
  addgroup --gid $docker_gid $docker_group
fi

if ! id -nG act | grep -qw "$docker_group"; then
  log INFO "Adding user [act] to group [$docker_group]..."
  usermod -aG $docker_group act
fi


#################################################################
# Launch the runner with adjusted UID/GID
#################################################################
exec sudo -u act -g act -E bash /opt/run_runner.sh
