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
    [[ $EUID -eq 0 ]] || sudo -E bash ${BASH_SOURCE[0]}
    log INFO "Changing UID of user [act] from $effective_uid to $GITEA_RUNNER_UID..."
    usermod -o -u "$GITEA_RUNNER_UID" act
  fi
fi

if [ -n "${GITEA_RUNNER_GID:-}" ]; then
  effective_gid=$(id -g act)
  if [ "$GITEA_RUNNER_GID" != "$effective_gid" ]; then
    [[ $EUID -eq 0 ]] || sudo -E bash ${BASH_SOURCE[0]}
    log INFO "Changing GID of user [act] from $effective_gid to $GITEA_RUNNER_GID..."
    groupmod -o -g "$GITEA_RUNNER_GID" act
  fi
fi
chown -R act:act /data


#################################################################
# Launch the runner with adjusted UID/GID
#################################################################
exec sudo -u act -g act -E bash /opt/run_runner.sh
