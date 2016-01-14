#!/bin/bash

set -e

if ! which juju 2>/dev/null; then
        sudo add-apt-repository ppa:juju/stable
        sudo apt-get update && sudo apt-get install juju-core
fi
if !which knife 2>/dev/null; then
        curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi


if [ -d /root/.juju/environments ]; then
	rm /root/.juju/environments/<env_name>*
fi

echo "" > /root/.juju/environments.yaml

echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " " >> /root/.juju/environments.yaml
 
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: gce" >> /root/.juju/environments.yaml
echo "      region: <region>" >> /root/.juju/environments.yaml
echo "      project-id: <project_id>" >> /root/.juju/environments.yaml
echo "      auth-file: <auth_file>" >> /root/.juju/environments.yaml

