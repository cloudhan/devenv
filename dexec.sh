#!/bin/bash

# NOTE: the lifetime socket referenced by env VSCODE_IPC_HOOK_CLI is bound to the terminal tab of VSCode
# so I must pass it on the terminal tab that executes `docker exec`

docker exec -it hgy-trtllm-devcontainer fish --init-command="\
  export VSCODE_GIT_ASKPASS_NODE=${VSCODE_GIT_ASKPASS_NODE} && \
  export VSCODE_GIT_ASKPASS_EXTRA_ARGS=${VSCODE_GIT_ASKPASS_EXTRA_ARGS} && \
  export VSCODE_GIT_IPC_HANDLE=${VSCODE_GIT_IPC_HANDLE} && \
  export VSCODE_GIT_ASKPASS_MAIN=${VSCODE_GIT_ASKPASS_MAIN} && \
  export VSCODE_IPC_HOOK_CLI=${VSCODE_IPC_HOOK_CLI} && \
  alias code (dirname $VSCODE_GIT_ASKPASS_NODE)/bin/remote-cli/code && \
  if test -e $PWD; cd $PWD; else; set_color red; echo '$PWD does not exist in container'; set_color normal; cd ~/workspaces; end"
