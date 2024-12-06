#!/bin/bash

if [[ ! $(hostname -s) =~ "computelab" ]]; then
  if [[ -e ~/.nodeenv/$(hostname -s) ]]; then
    export $(cat ~/.nodeenv/$(hostname -s) | grep -E '(SLURM|GPU|DEV)')
  else
    printf "\x1B[31m  ~/.nodeenv/$SLURMD_NODENAME does not exist, start node with:\n\n    crun -p 'env>~/.nodeenv/\$SLURMD_NODENAME' -e 'rm ~/.nodeenv/\$SLURMD_NODENAME' \n\n\x1B[0m"
  fi
fi
