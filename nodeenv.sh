#!/bin/bash

# jump machine patterns

if [[ $(hostname -s) =~ (computelab|container-xterm) ]]; then
  printf "\x1B[32mTip: You are on a jump machine ($(hostname -s))\x1B[0m\n"
else
  if [[ -e ~/.nodeenv/$(hostname -s) ]]; then
    export $(cat ~/.nodeenv/$(hostname -s) | grep -E '(SLURM|GPU|DEV)')
  else
    printf "\x1B[31m  ~/.nodeenv/$SLURMD_NODENAME does not exist, start node with:\n\n    crun -p 'env>~/.nodeenv/\$SLURMD_NODENAME' -e 'rm ~/.nodeenv/\$SLURMD_NODENAME' \n\n\x1B[0m"
  fi
fi
