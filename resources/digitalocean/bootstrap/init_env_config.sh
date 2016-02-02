#!/bin/bash

set -e 

if ! (which juju 2>/dev/null); then
	echo "Installing Juju.. "
	sudo add-apt-repository ppa:juju/stable -y
	sudo apt-get update && sudo apt-get install juju-core -y
fi

sudo apt-get install curl -y

if ! which knife 2>&1; then
	echo "Installing chef.. "
	curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi
 
mkdir -p /root/.chef 

sudo apt-get install juju python-pip -y
sudo pip install juju-docean  || { echo "ERROR installing digitalocean API "; exit 2 ;}
sudo pip install -U juju-docean || { echo "ERROR installing digitalocean API "; exit 2 ;}

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

if [ -f /root/.juju/ssh/juju_id_rsa  ]; then
	echo "Copying juju keys to the main '/root/.ssh/' dir "
	cp /root/.juju/ssh/juju_* /root/.ssh/
	echo "backing up original ssh keys to /tmp/backup_ssh"
	mkdir -p /tmp/backup_ssh 
	if [ -f /root/.ssh/id_rsa ]; then
		mv /root/.ssh/id_rsa /tmp/backup_ssh/
		mv /root/.ssh/id_rsa.pub /tmp/backup_ssh/
	fi
	mv  /root/.ssh/juju_id_rsa /root/.ssh/id_rsa
	mv  /root/.ssh/juju_id_rsa.pub /root/.ssh/id_rsa.pub
	echo "If bootstrap fails on the ssh key please verify you have upladed the : /root/.ssh/id_rsa.pub to digital ocean console and verified that you provided the correct SSH_KEY_NAME parameter"
fi
	
