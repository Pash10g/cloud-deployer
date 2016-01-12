#!/bin/bash

set -e

if ! which juju 2>/dev/null; then
	sudo add-apt-repository ppa:juju/stable
	sudo apt-get update && sudo apt-get install juju-core
fi

if !which knife 2>/dev/null; then
	curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi
 
cp  /root/.juju/environments.yaml  /root/.juju/environments.yaml_old

#juju generate-config -f || { echo "ERROR Failed to create juju environments.yaml file" ; exit 2 }

echo "" > /root/.juju/environments.yaml

echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " "
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: ec2" >> /root/.juju/environments.yaml
echo "      region: <region>" >> /root/.juju/environments.yaml
echo "      access-key: <access_key>" >> /root/.juju/environments.yaml
echo "      secret-key:  <secret_key>" >> /root/.juju/environments.yaml

