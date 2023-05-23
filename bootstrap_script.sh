#!/bin/bash

set -e

dnf upgrade --refresh -y

# from https://docs.fedoraproject.org/en-US/epel/#_el9
dnf install -y 'dnf-command(config-manager)'
dnf config-manager --set-enabled crb
dnf install -y epel-release epel-next-release

# we set EPEL enabled repos as high priority
EPEL_REPOS="/etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-next.repo"
sed -i '/cost=.*$/d' $EPEL_REPOS
sed -i '/enabled=1/a cost=2000' $EPEL_REPOS

# we install centos9-antelope trunk repos
curl -o /etc/yum.repos.d/delorean.repo \
	https://trunk.rdoproject.org/centos9-antelope/puppet-passed-ci/delorean.repo
curl -o /etc/yum.repos.d/delorean-deps.repo \
	https://trunk.rdoproject.org/centos9-antelope/delorean-deps.repo

# install some utilities
dnf install -y \
	less \
	vim \
	python3-virtualenv \
	git
