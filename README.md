## CUDA

```
# docker build -f Dockerfile.cuda . -t devimage
DOCKER_BUILDKIT=0 sudo -E docker build -f Dockerfile.cuda . -t devimage
docker run -it --gpus all --privileged devimage
micromamba activate
```
