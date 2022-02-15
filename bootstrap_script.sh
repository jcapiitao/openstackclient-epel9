#!/bin/bash

set -e

sudo dnf upgrade --refresh -y

# from https://docs.fedoraproject.org/en-US/epel/#_el9
sudo dnf install -y \
	less \
	vim \
	'dnf-command(config-manager)' \
	python3-virtualenv \
	git
sudo dnf config-manager --set-enabled crb
sudo dnf install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm

# we set EPEL enabled repos as high priority
EPEL_REPOS="/etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-next.repo"
sudo sed -i '/cost=.*$/d' $EPEL_REPOS
sudo sed -i '/enabled=1/a cost=2000' $EPEL_REPOS

# we install centos9-xena trunk repos
sudo curl -o /etc/yum.repos.d/delorean.repo \
	https://trunk.rdoproject.org/centos9-xena/current-passed-ci/delorean.repo
sudo curl -o /etc/yum.repos.d/delorean-deps.repo \
	https://trunk.rdoproject.org/centos9-xena/delorean-deps.repo
