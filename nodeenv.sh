#!/bin/bash

# jump machine patterns

if [[ $(hostname -s) =~ (computelab|container-xterm|ipp1-1428|ipp1-1429|ipp1-1334) ]]; then
  printf "\x1B[32mTip: You are on a jump machine ($(hostname -s))\x1B[0m\n"
else
  printf "\x1B[32mTip: You are on a compute node ($(hostname -s))\x1B[0m\n"
  if [[ -e ~/.nodeenv/$(hostname -s) ]]; then
    export $(cat ~/.nodeenv/$(hostname -s) | grep -E '(SLURM|GPU|DEV)')
  else
    printf "\x1B[31m  ~/.nodeenv/$SLURMD_NODENAME does not exist, start node with:\n\n    crun -p ~/workspaces/devenv/write_node_env.sh \n\n\x1B[0m"
  fi
fi
