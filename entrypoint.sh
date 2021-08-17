#!/bin/bash
set -ex -o errexit -o pipefail -o nounset

setup_docker() {
  dockerd-rootless-setuptool.sh install --skip-iptables
  export XDG_RUNTIME_DIR=/home/runner/.docker/run
  export PATH=/usr/bin:$PATH
  export DOCKER_HOST=unix:///home/runner/.docker/run/docker.sock
}

register_runner() {
  mkdir work-dir
  cd actions-runner

  # Grab a runner registration token
  REGISTRATION_TOKEN=$(curl -s -X POST \
      -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" \
      "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" | jq -r .token)

  UNIQUE_ID=$(uuidgen)

  # Register the runner
  ./config.sh \
        --unattended \
        --url "https://github.com/${REPO_OWNER}/${REPO_NAME}" \
        --token "${REGISTRATION_TOKEN}" \
        --name "${UNIQUE_ID}" \
        --work ../work-dir \
        --replace
}

cleanup() {
  # give the job a second to finish
  sleep 1
  # Deregister the runner from github
  REGISTRATION_TOKEN=$(curl -s -XPOST \
      -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" \
      "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" | jq -r .token)
  ./config.sh remove --token "${REGISTRATION_TOKEN}"

  # Remove our runner work dir to clean up after ourselves
  rm -rf ../work-dir
}

# Run cleanup upon exit. exit upon one job ran
setup_docker
trap cleanup EXIT
register_runner

./run.sh --once
