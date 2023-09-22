#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
source /opt/bash-init.sh

act_user=act

#################################################################
# Adjust UID/GID and file permissions based on env var config
#################################################################
if [ -n "${GITEA_RUNNER_UID:-}" ]; then
  effective_uid=$(id -u $act_user)
  if [ "$GITEA_RUNNER_UID" != "$effective_uid" ]; then
    log INFO "Changing UID of user [$act_user] from $effective_uid to $GITEA_RUNNER_UID..."

    # workaround for:
    #    usermod -o -u "$GITEA_RUNNER_UID" $act_user
    # failing with "usermod: user act is currently used by process 1" because of /usr/bin/tini process
    effective_gid=$(id -g $act_user)
    sed -i "s/^$act_user:x:$effective_uid:$effective_gid/$act_user:x:$GITEA_RUNNER_UID:$effective_gid/" /etc/passwd

    act_home=$(eval echo "~$act_user")
    chown $GITEA_RUNNER_UID "$act_home"
    find "$act_home" -user $effective_uid -exec chown $GITEA_RUNNER_UID {} \;
  fi
fi

if [ -n "${GITEA_RUNNER_GID:-}" ]; then
  effective_gid=$(id -g $act_user)
  if [ "$GITEA_RUNNER_GID" != "$effective_gid" ]; then
    log INFO "Changing GID of user [$act_user] from $effective_gid to $GITEA_RUNNER_GID..."
    groupmod -o -g "$GITEA_RUNNER_GID" $act_user

    act_home=$(eval echo "~$act_user")
    chown :$GITEA_RUNNER_GID "$act_home"
    find "$act_home" -group $effective_gid -exec chgrp $GITEA_RUNNER_GID {} \;
  fi
fi


#################################################################
# ensure act user has read/write access to /var/run/docker.sock
#################################################################
if [[ $DOCKER_MODE != "dind-rootless" ]]; then
  docker_sock=/var/run/docker.sock
  if runuser -u $act_user -- [ ! -r $docker_sock ] || runuser -u $act_user -- [ ! -w $docker_sock ]; then
    docker_group=$(stat -c '%G' $docker_sock)
    if [[ $docker_group == "UNKNOWN" ]]; then
      docker_gid=$(stat -c '%g' $docker_sock)
      docker_group="docker$docker_gid"
      log INFO "Creating group [$docker_group]..."
      addgroup --gid $docker_gid $docker_group
    fi

    if ! id -nG $act_user | grep -qw "$docker_group"; then
      log INFO "Adding user [$act_user] to docker group [$(getent group $docker_group)]..."
      usermod -aG $docker_group $act_user
    fi
  fi
fi


#################################################################
# Launch the runner via act user with adjusted UID/GID/group membership
#################################################################
exec sudo -u $act_user -g $act_user -E bash /opt/run_runner.sh
