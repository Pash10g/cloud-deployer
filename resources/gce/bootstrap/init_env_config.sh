#!/bin/bash

if ! which juju 2>/dev/null; then
	sudo add-apt-repository ppa:juju/stable -y
	sudo apt-get update && sudo apt-get install juju-core -y
fi

sudo apt-get  install curl -y

if ! which knife 2>/dev/null; then
        curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi


if [ -d /root/.juju/environments ]; then
	rm -rf /root/.juju/environments/<env_name>*
fi

mkdir -p /root/.chef/

juju generate-config -f || { echo "Failed to generate init configuration "; exit 2; }
echo "" > /root/.juju/environments.yaml

echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " " >> /root/.juju/environments.yaml
 
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: gce" >> /root/.juju/environments.yaml
echo "      region: <region>" >> /root/.juju/environments.yaml
echo "      project-id: <project_id>" >> /root/.juju/environments.yaml
echo "      auth-file: <auth_file>" >> /root/.juju/environments.yaml

