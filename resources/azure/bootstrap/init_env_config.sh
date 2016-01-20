#!/bin/bash
if ! which juju 2>/dev/null; then
        sudo add-apt-repository ppa:juju/stable -y
        sudo apt-get update -y && sudo apt-get install juju-core -y
fi
if ! which knife 2>/dev/null; then
        curl -L https://www.opscode.com/chef/install.sh | sudo bash
fi

if ! which azure 2>/dev/null; then
	sudo apt-get install nodejs-legacy -y
	sudo apt-get install npm -y
	sudo npm install -g azure-cli
	echo "azure cli installed"
fi
azure config mode arm
if ! azure account show 2>/dev/null; then
	echo "Setting up first login"
	azure login || { echo "ERROR ! Failed to login into azure account... "; exit 2; }
fi	


#azure role assignment create --objectId 146c9e6b-e9a0-454c-9e0a-1f85190ca17d -o Owner -c /subscriptions/	
#
if [ -d /root/.juju/environments ]; then
	rm /root/.juju/environments/<env_name>*
fi

echo "" > /root/.juju/environments.yaml


echo "default: <env_name>" >> /root/.juju/environments.yaml
echo "environments:" >> /root/.juju/environments.yaml
echo " " >> /root/.juju/environments.yaml
echo "    <env_name>:" >> /root/.juju/environments.yaml
echo "      type: azure" >> /root/.juju/environments.yaml
echo "      application-id: <application_id>" >> /root/.juju/environments.yaml
echo "      application-password: <application_password>" >> /root/.juju/environments.yaml
echo "      subscription-id: <subscription_id>" >> /root/.juju/environments.yaml
echo "      tenant-id: <tenant_id>" >> /root/.juju/environments.yaml
echo "      location: <region>" >> /root/.juju/environments.yaml


#
#if [ -d /root/.juju/environments ]; then
#	rm /root/.juju/environments/<env_name>*
#fi
#
#echo "" > /root/.juju/environments.yaml

