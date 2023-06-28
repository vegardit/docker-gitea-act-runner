# vegardit/gitea-act-runner <a href="https://github.com/vegardit/docker-gitea-act-runner/" title="GitHub Repo"><img height="30" src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/github.svg?sanitize=true"></a>

[![Build Status](https://github.com/vegardit/docker-gitea-act-runner/workflows/Build/badge.svg "GitHub Actions")](https://github.com/vegardit/docker-gitea-act-runner/actions?query=workflow%3ABuild)
[![License](https://img.shields.io/github/license/vegardit/docker-gitea-act-runner.svg?label=license)](#license)
[![Docker Pulls](https://img.shields.io/docker/pulls/vegardit/gitea-act-runner.svg)](https://hub.docker.com/r/vegardit/gitea-act-runner)
[![Docker Stars](https://img.shields.io/docker/stars/vegardit/gitea-act-runner.svg)](https://hub.docker.com/r/vegardit/gitea-act-runner)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

1. [What is it?](#what-is-it)
1. [Usage](#usage)
1. [License](#license)


## <a name="what-is-it"></a>What is it?

`debian:stable-slim` based Docker image containing [Gitea](https://gitea.com)'s [act_runner](https://gitea.com/gitea/act_runner/)

#### Why not using Alpine Linux?
- musl-libc - Alpine's Greatest Weakness https://www.linkedin.com/pulse/musl-libc-alpines-greatest-weakness-rogan-lynch
- Why I will never use Alpine Linux ever again https://martinheinz.dev/blog/92
- Does Alpine have known DNS issue within Kubernetes? https://stackoverflow.com/questions/65181012/
- Why is the Alpine Docker image over 50% slower than the Ubuntu image? https://superuser.com/questions/1219609/
- Performance issue with alpine musl library https://unix.stackexchange.com/questions/729342/


## <a name="usage"></a>Usage

The docker image comes in three flavors:
- `vegardit/gitea-act-runner:latest`: only contains the Gitea act_runner and executes workflows in containers of the docker engine running act_runner itself (DooD / Docker-out-of-Docker approach)
- `vegardit/gitea-act-runner:dind-latest`: executes workflows using an embedded docker engine (DinD / Docker-in-Docker approach) providing better process isolation
- `vegardit/gitea-act-runner:dind-rootless-latest`: executes workflows using an embedded docker engine (DinD / Docker-in-Docker approach) running the docker deamon as a non-root user [(Rootless mode)](https://docs.docker.com/engine/security/rootless/)

### Docker Run

Running from the command line:

- Docker-out-of-Docker approach
   ```sh
     docker run \
       -e GITEA_INSTANCE_URL=https://gitea.example.com \
       -e GITEA_RUNNER_REGISTRATION_TOKEN=<INSERT_TOKEN_HERE> \
       -v /var/run/docker.sock:/var/run/docker.sock:rw \
       --name gitea_act_runner \
       vegardit/gitea-act-runner:latest
   ```

- Docker-in-Docker approach
   ```sh
     docker run \
       -e GITEA_INSTANCE_URL=https://gitea.example.com \
       -e GITEA_RUNNER_REGISTRATION_TOKEN=<INSERT_TOKEN_HERE> \
       --privileged
       --name gitea_act_runner \
       vegardit/gitea-act-runner:dind-latest
   ```

- Docker-in-Docker approach with Docker daemon running as a non-root user (Rootless mode)
   ```sh
     docker run \
       -e GITEA_INSTANCE_URL=https://gitea.example.com \
       -e GITEA_RUNNER_REGISTRATION_TOKEN=<INSERT_TOKEN_HERE> \
       --privileged
       --name gitea_act_runner \
       vegardit/gitea-act-runner:dind-rootless-latest
   ```

### Docker Compose

Example `docker-compose.yml`:

- Docker-out-of-Docker approach
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
         GITEA_RUNNER_REGISTRATION_TOKEN_FILE: 'path/to/file' # one-time registration token, only required on first container start
         # or: GITEA_RUNNER_REGISTRATION_TOKEN: '<INSERT_TOKEN_HERE>'
   ```

- Docker-in-Docker approach
   ```yaml
   version: '3.8' # https://docs.docker.com/compose/compose-file/compose-versioning/

   services:

     gitea_act_runner:
       image: vegardit/gitea-act-runner:dind-latest
       privileged: true
       volumes:
         - /my/path/to/data/dir:/data:rw # the config file is located at /data/.runner and needs to survive container restarts
       environment:
         TZ: "Europe/Berlin"
         # config parameters for initial runner registration:
         GITEA_INSTANCE_URL: 'https://gitea.example.com' # required
         GITEA_RUNNER_REGISTRATION_TOKEN_FILE: 'path/to/file' # one-time registration token, only required on first container start
         # or: GITEA_RUNNER_REGISTRATION_TOKEN: '<INSERT_TOKEN_HERE>'
   ```

### Additional environment variables

The following environment variables can be specified to further configure the service.

#### Runner registration:
Name|Default Value|Description
----|-------------|-----------
GITEA_INSTANCE_INSECURE|`false`|It `true` don't verify the TLS certificate of the Gitea instance
GITEA_RUNNER_NAME|`<empty>`|If not specified the container's hostname is used
GITEA_RUNNER_LABELS|`<empty>`|Comma-separated list of labels in the format of `label[:schema[:args]]`. If not specified the following labels are used `ubuntu-latest:docker://catthehacker/ubuntu:runner-22.04,ubuntu-22.04:docker://catthehacker/ubuntu:runner-22.04,ubuntu-20.04:docker://catthehacker/ubuntu:runner-20.04`
GITEA_RUNNER_REGISTRATION_FILE|`/data/.runner`|The JSON file that holds the result from the runner registration with the Gitea instance
GITEA_RUNNER_REGISTRATION_TIMEOUT|`30`|In case of failure, registration is retried until this timeout in seconds is reached
GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL|`5`|Wait period in seconds between registration retries

#### Runner runtime config:

Name|Default Value|Description
----|-------------|-----------
GITEA_RUNNER_CONFIG_TEMPLATE_FILE|`/opt/config.template.yaml`|Template to derive the effective config file from, see [image/config.template.yaml](image/config.template.yaml)
GITEA_RUNNER_UID|`1000`|The UID of the Gitea runner process
GITEA_RUNNER_GID|`1000`|The GID of the Gitea runner process
GITEA_RUNNER_LOG_LEVEL|`info`|The level of logging, can be trace, debug, info, warn, error, fatal
GITEA_RUNNER_ENV_FILE|`/data/.env`|Extra environment variables to run jobs from a file
GITEA_RUNNER_FETCH_TIMEOUT|`5s`|The timeout for fetching the job from the Gitea instance
GITEA_RUNNER_FETCH_INTERVAL|`2s`|The interval for fetching the job from the Gitea instance
GITEA_RUNNER_MAX_PARALLEL_JOBS|`1`|Maximum number of concurrently executed jobs
GITEA_RUNNER_JOB_CONTAINER_NETWORK|`bridge`|Docker network to use with job containers. Can be `bridge`, `host`, `none`, or the name of a custom network
GITEA_RUNNER_JOB_CONTAINER_PRIVILEGED|`false`|Whether to run jobs in containers with privileged mode which is required for **Docker-in-Docker** aka **dind**
GITEA_RUNNER_JOB_CONTAINER_OPTIONS|`none`|Additional container launch options (eg, --add-host=my.gitea.url:host-gateway)
GITEA_RUNNER_JOB_CONTAINER_WORKDIR_PARENT|`/workspace`|The parent directory of a job's working directory.
GITEA_RUNNER_JOB_TIMEOUT|`3h`|The maximum time a job can run before it is cancelled
GITEA_RUNNER_ENV_VAR_**N**_NAME|`none`|Name of the **N**-th extra environment variable to be passed to Job containers, e.g. `GITEA_RUNNER_ENV_VAR_1_NAME=MY_AUTH_TOKEN`
GITEA_RUNNER_ENV_VAR_**N**_VALUE|`<empty>`|Value of the **N**-th extra environment variable to be passed to Job containers, e.g. `GITEA_RUNNER_ENV_VAR_1_VALUE=SGVsbG8gbXkgZnJpZW5kIQ==`
GITEA_RUNNER_ACTION_CACHE_DIR|`/data/cache/actions`|Path to cache cloned actions

#### Embedded cache server:
Name|Default Value|Description
----|-------------|-----------
ACT_CACHE_SERVER_ENABLED|`true`| Enable the embedded cache service to use `actions/cache` in jobs
ACT_CACHE_SERVER_DIR|`/data/cache/server`| The directory to store the cache data
ACT_CACHE_SERVER_HOST|`<empty>`| The IP address or hostname via which the job containers can reach the cache server. Leave empty for automatic detection
ACT_CACHE_SERVER_PORT|`0`|The TCP port of the cache server. `0` means to use a random, available port


## <a name="license"></a>License

All files in this repository are released under the [Apache License 2.0](LICENSE.txt).

Individual files contain the following tag instead of the full license text:
```
SPDX-License-Identifier: Apache-2.0
```

This enables machine processing of license information based on the SPDX License Identifiers that are available here: https://spdx.org/licenses/.
