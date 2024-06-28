#!/bin/bash

PPA_USER=$(echo $1 | cut -d/ -f1)
PPA_REPO=$(echo $1 | cut -d/ -f2)
PPA_KEY=$2
CODENAME=$(grep UBUNTU_CODENAME /etc/os-release | cut -d= -f2)

echo "deb https://ppa.launchpadcontent.net/${PPA_USER}/${PPA_REPO}/ubuntu/ ${CODENAME} main" > /etc/apt/sources.list.d/${PPA_USER}-${PPA_REPO}.list
gpg --no-default-keyring --keyring /tmp/add-ppa.gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys ${PPA_KEY}
gpg --no-default-keyring --keyring /tmp/add-ppa.gpg --export ${PPA_KEY} > /etc/apt/trusted.gpg.d/${PPA_USER}-${PPA_REPO}.gpg
gpg --no-default-keyring --keyring /tmp/add-ppa.gpg --batch --yes --delete-keys ${PPA_KEY}
rm /tmp/add-ppa.gpg

