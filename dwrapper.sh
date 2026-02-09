#!/bin/bash

set -euo pipefail

cd "$(dirname "$(realpath "$0")")"

TAG=""
FORCE_BUILD=0
QUIET=0

parse_tag_and_flags() {
    # Parses: [<tag>] [-f] [-q]
    TAG=""
    FORCE_BUILD=0
    QUIET=0

    if [[ ${1:-} != "" && ${1:-} != -* ]]; then
        TAG="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f)
                FORCE_BUILD=1
            ;;
            -q)
                QUIET=1
            ;;
            *)
                return 2
            ;;
        esac
        shift
    done

    return 0
}

subcommand="${1:-}"
[[ -n "$subcommand" ]] || exit 2
shift || true

parse_tag_and_flags "$@"

IMAGE_NAME="hgy-devimage${TAG:+-$TAG}"
CONTAINER_NAME="hgy-devcontainer${TAG:+-$TAG}"


image_exists() {
    if [[ $QUIET -ne 1 ]]; then
        echo "Checking if image $IMAGE_NAME exists..."
    fi
    docker image inspect "$IMAGE_NAME" > /dev/null 2>&1 && return 0 || return -1
}

container_exists() {
    if [[ $QUIET -ne 1 ]]; then
        echo "Checking if container $CONTAINER_NAME exists..."
    fi
    docker container inspect "$CONTAINER_NAME" > /dev/null 2>&1 && return 0 || return -1
}

# echo "TAG=$TAG"
# echo "FORCE_BUILD=$FORCE_BUILD"
# echo "QUIET=$QUIET"
# echo "IMAGE_NAME=$IMAGE_NAME"
# echo "CONTAINER_NAME=$CONTAINER_NAME"

build() {
    if [[ $FORCE_BUILD -eq 1 ]] || ! image_exists; then
        echo "Building $IMAGE_NAME..."
        docker build \
        -f Dockerfile${TAG:+.$TAG} \
        -t $IMAGE_NAME \
        .
    else
        if [[ $QUIET -ne 1 ]]; then
            echo "Image $IMAGE_NAME already exists. Use -f to force rebuild."
        fi
    fi
}

run() {
    local nv_gpu
    local gpus_arg

    # default to all GPUs if unset/empty.
    nv_gpu="${NV_GPU:-}"
    if [[ -n "$nv_gpu" ]]; then
        gpus_arg="device=$nv_gpu"
    else
        gpus_arg="all"
    fi

    echo "Starting $CONTAINER_NAME..."

    docker run \
        --runtime nvidia --gpus "$gpus_arg" \
        --name "$CONTAINER_NAME" -dit --init --rm\
        --ulimit memlock=-1 --cap-add=SYS_ADMIN \
        --network host \
        -e HGY_HOST_UID="$(id -u)" \
        -e HGY_DOCKER_ENV=1 \
        --mount type=bind,source=/home,target=/home,bind-propagation=rslave \
        --mount type=bind,source=/tmp,target=/tmp \
        "$IMAGE_NAME" \
        sleep infinity
}

exec() {
    # NOTE: the lifetime socket referenced by env VSCODE_IPC_HOOK_CLI is bound to the terminal tab of VSCode
    # so I must pass it on the terminal tab that executes `docker exec`

    echo "Trying to exec into $CONTAINER_NAME..."

    # export VSCODE_GIT_ASKPASS_NODE=${VSCODE_GIT_ASKPASS_NODE} && \
    # export VSCODE_GIT_ASKPASS_EXTRA_ARGS=${VSCODE_GIT_ASKPASS_EXTRA_ARGS} && \
    # export VSCODE_GIT_IPC_HANDLE=${VSCODE_GIT_IPC_HANDLE} && \
    # export VSCODE_GIT_ASKPASS_MAIN=${VSCODE_GIT_ASKPASS_MAIN} && \
    # export VSCODE_IPC_HOOK_CLI=${VSCODE_IPC_HOOK_CLI} && \
    # alias code (dirname $VSCODE_GIT_ASKPASS_NODE)/bin/remote-cli/code && \
    docker exec -it "$CONTAINER_NAME" fish --init-command="\
    if test -e $PWD; cd $PWD; else; set_color red; echo '$PWD does not exist in container'; set_color normal; cd ~/workspaces; end"
}

case "$subcommand" in
    build)
        build
    ;;

    run)
        image_exists || build
        run
    ;;

    exec)
        image_exists || build
        container_exists || run
        exec
    ;;

    *)
        exit -1
    ;;
esac
