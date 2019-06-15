#!/bin/bash
#
#  Install host prerequisites
#
PNAME=${0##*\/}

sudo yum install -y java-1.8.0-openjdk wget tmux htop
sudo yum erase -y mariadb-libs


exit 0

