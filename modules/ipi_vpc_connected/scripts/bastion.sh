#!/bin/bash

echo "Download the openshift installer and CLI"
curl -LfO http://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-install-linux.tar.gz
curl -LfO http://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-client-linux.tar.gz

echo "Unpack the tarballs into /usr/local/bin/"
tar xvf openshift-install-linux.tar.gz -C /usr/local/bin/
tar xvf openshift-client-linux.tar.gz -C /usr/local/bin

echo "Clean Up the download artifacts"
rm -rf openshift-*

echo "Install some core packages and run yum update"
dnf install -y podman git vim tmux make golang
dnf update -y --security

echo "Create deployment scaffolding"
mkdir /home/ec2-user/backup
mkdir /home/ec2-user/deployment
mkdir /home/ec2-user/.aws
chown -R ec2-user:ec2-user /home/ec2-user/
