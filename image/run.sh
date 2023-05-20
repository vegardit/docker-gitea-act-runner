#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner
#
source /opt/bash-init.sh

#################################################
# print header
#################################################
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

exec sudo -E bash /opt/run_fixids.sh
