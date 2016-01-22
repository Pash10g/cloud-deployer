#!/bin/bash


if ! (which juju 2>/dev/null); then
	sudo apt-get install juju -y 
fi

if ! which knife 2>&1; then
	curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi
 
sudo add-apt-repository ppa:juju/stable -y
sudo apt-get update -y
sudo apt-get install juju python-pip -y
sudo pip install juju-docean  || { echo "ERROR installing digitalocean API "; exit 2 ;}

cp "" > /root/.juju/environments.yaml


echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: manual" >> /root/.juju/environments.yaml
echo "      bootstrap-host: null" >> /root/.juju/environments.yaml
echo "      bootstrap-user: root" >> /root/.juju/environments.yaml
echo "export  DO_OAUTH_TOKEN=\"<ac_key>\"" >> ~/.bashrc
echo "export DO_SSH_KEY=\"<ssh_key_name>\""  >> ~/.bashrc
source ~/.bashrc

