#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
source /opt/bash-init.sh

log INFO "Effective user: $(id)"

cd /data

#################################################
# load custom init script if specified
#################################################
if [[ -f $INIT_SH_FILE ]]; then
  log INFO "Loading [$INIT_SH_FILE]..."
  source "$INIT_SH_FILE"
fi


#################################################
# register act runner if required
#################################################
if [[ ! -s .runner ]]; then
  if [[ ${GITEA_INSTANCE_INSECURE:-} == '1' ]]; then
    insecure_flag=--insecure
  fi
  if [[ -z ${GITEA_RUNNER_REGISTRATION_TOKEN:-} ]]; then
    read -r GITEA_RUNNER_REGISTRATION_TOKEN < "$GITEA_RUNNER_REGISTRATION_TOKEN_FILE"
  fi
  act_runner register \
    --instance "${GITEA_INSTANCE_URL}" \
    --token    "${GITEA_RUNNER_REGISTRATION_TOKEN}" \
    --name     "${GITEA_RUNNER_NAME}" \
    --labels   "${GITEA_RUNNER_LABELS}" \
    $( [[ ${GITEA_INSTANCE_INSECURE:-} == '1' ]] && echo "--insecure" || true) \
    --no-interactive
fi


#################################################
# run the act runner
#################################################
exec act_runner daemon
