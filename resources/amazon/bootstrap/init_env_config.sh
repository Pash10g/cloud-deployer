#!/bin/bash

set -e

if ! which juju 2>/dev/null; then
	echo "Installing juju..."
	sudo add-apt-repository ppa:juju/stable -y
	sudo apt-get update && sudo apt-get install juju-core -y
fi

if ! which knife 2>/dev/null; then
	echo "Installing chef workstation..."
	curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi
 


#juju generate-config -f || { echo "ERROR Failed to create juju environments.yaml file" ; exit 2 }


if [ -f /root/.juju/environments/<env_name>.json ]; then
	rm  /root/.juju/environments/<env_name>.json
fi

echo "Genrating juju configuration for env : '<env_name>'"
juju generate-config -f 

echo "" > /root/.juju/environments.yaml

echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " "
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: ec2" >> /root/.juju/environments.yaml
echo "      region: <region>" >> /root/.juju/environments.yaml
echo "      access-key: <access_key>" >> /root/.juju/environments.yaml
echo "      secret-key:  <secret_key>" >> /root/.juju/environments.yaml

