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

mkdir -p /root/.chef/


echo "Genrating juju configuration for env : '<env_name>'"
juju generate-config -f 

echo "" > /root/.juju/environments.yaml


echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " " >> /root/.juju/environments.yaml
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: azure" >> /root/.juju/environments.yaml
echo "      location:: <region>" >> /root/.juju/environments.yaml
echo "      management-subscription-id: <subscription_id:>" >> /root/.juju/environments.yaml
echo "      management-certificate-path: <management_certificate_path>" >> /root/.juju/environments.yaml
echo "      storage-account-name: <storage_account_name>" >> /root/.juju/environments.yaml



