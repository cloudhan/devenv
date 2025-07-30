#!/bin/bash

cd $(dirname $(realpath $0))
# base_image=$(grep 'LLM_DOCKER_IMAGE =' ~/workspaces/trtllm/jenkins/L0_MergeRequest.groovy  | sed 's#.*"\(.*\)"#\1#')

# updage tag  https://urm.nvidia.com/artifactory/sw-tensorrt-docker/tensorrt-llm/
base_image="urm.nvidia.com/sw-tensorrt-docker/tensorrt-llm:pytorch-25.05-py3-x86_64-ubuntu24.04-trt10.11.0.33-skip-tritondevel-202507101530-5434"
# base_image="urm.nvidia.com/sw-tensorrt-docker/tensorrt-llm:pytorch-25.06-py3-x86_64-ubuntu24.04-trt10.11.0.33-skip-tritondevel-202507161655-5678"

force_build=0
quiet=0
while getopts "fq" opt; do
  case $opt in
    f)
      force_build=1
      ;;
    q)
      quiet=1
      ;;
  esac
done

if [[ $force_build -eq 1 ]] || ! docker image inspect hgy-trtllm-devimage > /dev/null 2>&1; then
  echo "Building hgy-trtllm-devimage..."
  docker build \
    -f Dockerfile.trtllm \
    --build-arg BASE_IMAGE=${base_image} \
    -t hgy-trtllm-devimage \
    .
else
  if [[ $quiet -ne 1 ]]; then
    echo "Image hgy-trtllm-devimage already exists. Use -f to force rebuild."
  fi
fi
