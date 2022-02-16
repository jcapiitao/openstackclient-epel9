#!/bin/bash

rm -rf .venv
virtualenv -p /usr/bin/python3.9 .venv
source .venv/bin/activate

pip install rdopkg pymod2pkg
rdopkg info conf:rpmfactory-client | grep name: | awk '{print $2}' | sort > openstack_clients

sed -i '/python-tripleoclient/d' openstack_clients

> dependencies
while read client; do
	pkg_name=$(pymod2pkg $client --pyver py3)
	echo -e "# $pkg_name" | tee -a dependencies
	sudo dnf install $pkg_name <<< 'no' | grep -e delorean -e epel | tee -a dependencies
	echo -e "" >> dependencies
done < openstack_clients
