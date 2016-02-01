#!/bin/bash


if ! (which juju 2>/dev/null); then
	echo "Installing Juju.. "
	sudo add-apt-repository ppa:juju/stable -y
	sudo apt-get update && sudo apt-get install juju-core -y
fi

if ! which knife 2>&1; then
	echo "Installing chef.. "
	curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi
 

sudo apt-get install juju python-pip -y
sudo pip install juju-docean  || { echo "ERROR installing digitalocean API "; exit 2 ;}

if [ -f /root/.juju/environments/<env_name>.json ]; then
	rm  /root/.juju/environments/<env_name>.json
fi

echo "Genrating juju configuration for env : '<env_name>'"
juju generate-config -f 
echo "" > /root/.juju/environments.yaml

echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " " >> /root/.juju/environments.yaml
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: manual" >> /root/.juju/environments.yaml
echo "      bootstrap-host: null" >> /root/.juju/environments.yaml
echo "      bootstrap-user: root" >> /root/.juju/environments.yaml
echo "export  DO_OAUTH_TOKEN=\"<ac_key>\"" >> ~/.bashrc
echo "export DO_SSH_KEY=\"<ssh_key_name>\""  >> ~/.bashrc
source ~/.bashrc

