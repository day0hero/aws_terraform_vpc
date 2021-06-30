#!/bin/bash

echo "Download the openshift installer and CLI"
curl -LfO http://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-install-linux.tar.gz
curl -LfO http://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-client-linux.tar.gz

echo "Unpack the tarballs into /usr/local/bin/"
sudo tar xvf openshift-install-linux.tar.gz -C /usr/local/bin/
sudo tar xvf openshift-client-linux.tar.gz -C /usr/local/bin

echo "Clean Up the download artifacts"
rm -rf ~/openshift-*

echo "Install some core packages and run yum update"
sudo dnf install -y podman git vim tmux
sudo dnf update -y

echo "Create deployment scaffolding"
mkdir ~/{backup,deployment}
mkdir ~/.aws