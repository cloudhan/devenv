## CUDA

```bash
mkdir -p /home/guangyunhan/.cache/{pip,mamba,conda,huggingface}
# docker build -f Dockerfile.cuda . -t devimage
DOCKER_BUILDKIT=0 sudo -E docker build -f Dockerfile.cuda . -t devimage
docker run --name devcontainer -dit --privileged --network host -v $HOME:$HOME --gpus all devimage sleep infinity
micromamba activate
```

## ROCm

```bash
mkdir -p /home/guangyunhan/.cache/{pip,mamba,conda,huggingface}
docker build -f Dockerfile.rocm . -t devimage
docker run --name devcontainer -dit --privileged --network host -v $HOME:$HOME --device /dev/kfd --device /dev/dri devimage sleep infinity
micromamba activate
```
