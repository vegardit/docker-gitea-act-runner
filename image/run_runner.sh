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


#################################################################
# ensure act user has read/write access to /var/run/docker.sock
#################################################################
if [[ ! -w /var/run/docker.sock || ! -r /var/run/docker.sock ]]; then
  docker_group=$(stat -c '%G' /var/run/docker.sock)
  if [[ $docker_group == "UNKNOWN" ]]; then
    docker_gid=$(stat -c '%g' /var/run/docker.sock)
    docker_group="docker$docker_gid"
    log INFO "Creating group [$docker_group]..."
    sudo addgroup --gid $docker_gid $docker_group
  fi

  if ! id -nG act | grep -qw "$docker_group"; then
    log INFO "Adding user [act] to docker group [$(getent group $docker_group)]..."
    sudo usermod -aG $docker_group act
  fi
fi


#################################################
# load custom init script if specified
#################################################
if [[ -f "$INIT_SH_FILE" ]]; then
  log INFO "Loading [$INIT_SH_FILE]..."
  source "$INIT_SH_FILE"
fi


#################################################
# set cache config
#################################################
# workaround for actions cache dir not being fully configurable
# https://gitea.com/gitea/act/src/commit/62abf4fe116865f6edf85d6bce822050dd01ac78/pkg/runner/run_context.go#L360-L371
mkdir -p $GITEA_RUNNER_ACTION_CACHE_DIR
mkdir -p /tmp/.cache
ln -sfn $GITEA_RUNNER_ACTION_CACHE_DIR /tmp/.cache/act
export XDG_CACHE_HOME=/tmp/.cache


#################################################
# render config file
#################################################
effective_config_file=/tmp/gitea_act_runner_config.yml
rm -f "$effective_config_file"
if [[ ${GITEA_RUNNER_LOG_EFFECTIVE_CONFIG:-false} == "true" ]]; then
  log INFO "Effective runner config [$effective_config_file]:"
  while IFS= read -r line; do
    line=${line//\"/\\\"} # escape double quotes
    eval "echo \"$line\"" | tee -a "$effective_config_file"
  done < $GITEA_RUNNER_CONFIG_TEMPLATE_FILE
  echo
else
  while IFS= read -r line; do
    line=${line//\"/\\\"} # escape double quotes
    eval "echo \"$line\"" >> "$effective_config_file"
  done < $GITEA_RUNNER_CONFIG_TEMPLATE_FILE
fi


#################################################
# register act runner if required
#################################################
if [[ ! -s .runner ]]; then
  if [[ -z ${GITEA_RUNNER_REGISTRATION_TOKEN:-} ]]; then
    read -r GITEA_RUNNER_REGISTRATION_TOKEN < "$GITEA_RUNNER_REGISTRATION_TOKEN_FILE"
  fi

  if [[ -z ${GITEA_RUNNER_LABELS:-} ]]; then
    GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS_DEFAULT
  fi

  log INFO "Trying to register runner with Gitea..."
  log INFO "  GITEA_INSTANCE_URL=$GITEA_INSTANCE_URL"
  log INFO "  GITEA_RUNNER_NAME=$GITEA_RUNNER_NAME"
  log INFO "  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS"
  wait_until=$(( $(date +%s) + $GITEA_RUNNER_REGISTRATION_TIMEOUT ))
  while true; do
    if act_runner register \
      --instance "$GITEA_INSTANCE_URL" \
      --token    "$GITEA_RUNNER_REGISTRATION_TOKEN" \
      --name     "$GITEA_RUNNER_NAME" \
      --labels   "$GITEA_RUNNER_LABELS" \
      --config "$effective_config_file" \
      --no-interactive; then
      break;
    fi
    if [ "$(date +%s)" -ge $wait_until ]; then
      log ERROR "Runner registration failed."
      exit 1
    fi
    sleep "$GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL"
  done
fi


#################################################
# unset all variables named GITEA_... to prevent deprecation warning
#################################################
unset $(env | grep "^GITEA_" | cut -d= -f1)


#################################################
# run the act runner
#################################################
exec act_runner daemon --config "$effective_config_file"
