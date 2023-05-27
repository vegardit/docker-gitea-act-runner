#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
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

  log INFO "Timezone is $(date +"%Z %z")"
  log INFO "Hostname: $(hostname -f)"
  log INFO "IP Addresses: "
  awk '/32 host/ { if(uniq[ip]++ && ip != "127.0.0.1") print " - " ip } {ip=$2}' /proc/net/fib_trie
fi


#################################################################
# start docker deamon (if installed = DinD)
#################################################################
if [[ -f /usr/bin/dockerd ]]; then
  [[ $EUID -eq 0 ]] || sudo -E bash ${BASH_SOURCE[0]}
  log INFO "Starting docker engine..."
  sudo service docker start
  while [[ ! -e /var/run/docker.sock ]]; do sleep 2; done
fi


#################################################################
# check if act user UID/GID needs adjustment
#################################################################
fixids=false
if [ -n "${GITEA_RUNNER_UID:-}" ]; then
  effective_uid=$(id -u act)
  if [ "$GITEA_RUNNER_UID" != "$effective_uid" ]; then
    fixids=true
  fi
fi

if [ -n "${GITEA_RUNNER_GID:-}" ]; then
  effective_gid=$(id -g act)
  if [ "$GITEA_RUNNER_GID" != "$effective_gid" ]; then
    fixids=true
  fi
fi


#################################################################
# adjust act user UID/GID if required
#################################################################
if [[ $fixids == "true" ]]; then
  exec sudo -E bash /opt/run_fixids.sh
else
  bash /opt/run_runner.sh
fi
