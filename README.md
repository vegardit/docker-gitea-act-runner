# vegardit/gitea-act-runner <a href="https://github.com/vegardit/docker-gitea-act-runner/" title="GitHub Repo"><img height="30" src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/github.svg?sanitize=true"></a>

[![Build Status](https://github.com/vegardit/docker-gitea-act-runner/workflows/Build/badge.svg "GitHub Actions")](https://github.com/vegardit/docker-gitea-act-runner/actions?query=workflow%3ABuild)
[![License](https://img.shields.io/github/license/vegardit/docker-gitea-act-runner.svg?label=license)](#license)
[![Docker Pulls](https://img.shields.io/docker/pulls/vegardit/gitea-act-runner.svg)](https://hub.docker.com/r/vegardit/gitea-act-runner)
[![Docker Stars](https://img.shields.io/docker/stars/vegardit/gitea-act-runner.svg)](https://hub.docker.com/r/vegardit/gitea-act-runner)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

1. [What is it?](#what-is-it)
1. [License](#license)


## <a name="what-is-it"></a>What is it?

`debian:stable-slim` based Docker image containing [Gitea](https://gitea.com)'s [act_runner](https://gitea.com/gitea/act_runner/)


## Usage

Example `docker-compose.yml`:

```yaml
version: '3.8' # https://docs.docker.com/compose/compose-file/compose-versioning/

services:

  gitea_act_runner:
    image: vegardit/gitea-act-runner:latest
    #image: ghcr.io/vegardit/gitea-act-runner:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
      - /my/path/to/data/dir:/data:rw # the config file is located at /data/.runner and needs to survive container restarts
    environment:
      TZ: "Europe/Berlin"
      # config parameters for initial runner registration:
      GITEA_INSTANCE_URL: 'https://gitea.example.com' # required
      GITEA_INSTANCE_INSECURE: '0' # optional, default is 0
      GITEA_RUNNER_REGISTRATION_TOKEN_FILE: 'path/to/file' # only required on first container start
      # or: GITEA_RUNNER_REGISTRATION_TOKEN: '<INSERT_TOKEN_HERE>'
      GITEA_RUNNER_NAME: '' # optional, defaults to the container's hostname
      GITEA_RUNNER_LABELS: '' # optional
      GITEA_RUNNER_UID: 1200 # optional, default is 1000
      GITEA_RUNNER_GID: 1200 # optional, default is 1000
    deploy:
      restart_policy:
        condition: on-failure
        delay: 5s
```


## <a name="license"></a>License

All files in this repository are released under the [Apache License 2.0](LICENSE.txt).

Individual files contain the following tag instead of the full license text:
```
SPDX-License-Identifier: Apache-2.0
```

This enables machine processing of license information based on the SPDX License Identifiers that are available here: https://spdx.org/licenses/.
