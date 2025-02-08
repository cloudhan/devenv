#!/bin/bash

cd $(dirname $(realpath $0))

docker run \
  --runtime nvidia --gpus "device=$NV_GPU" \
  --name hgy-trtllm-devcontainer -dit --rm\
  --ulimit memlock=-1 --cap-add=SYS_ADMIN \
  --network host \
  -e HGY_HOST_UID=$(id -u) \
  -e HGY_DOCKER_ENV=1 \
  --mount type=bind,source=/home,target=/home,bind-propagation=rslave \
  --mount type=bind,source=/tmp,target=/tmp,bind-propagation=rslave \
  hgy-trtllm-devimage \
  sleep infinity
