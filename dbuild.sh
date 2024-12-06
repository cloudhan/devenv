#!/bin/bash

cd $(dirname $(realpath $0))
base_image=$(grep 'LLM_DOCKER_IMAGE =' ~/workspaces/trtllm/jenkins/L1_Nightly.groovy  | sed 's#.*"\(.*\)"#\1#')
docker build \
  -f Dockerfile.trtllm \
  --build-arg BASE_IMAGE=${base_image} \
  -t hgy-trtllm-devimage \
  .
