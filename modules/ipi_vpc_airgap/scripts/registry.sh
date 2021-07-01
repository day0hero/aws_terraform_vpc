#!/bin/bash

#Update security findings
dnf update -y --security 

#Install registry packages
dnf install -y podman vim tmux httpd-tools firewalld

#Start and Enable firewalld service
systemctl enable --now firewalld

firewall-cmd --add-service=5000/tcp --permanent
firewall-cmd --reload



