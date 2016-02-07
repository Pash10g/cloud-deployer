#!/bin/bash

set -e

FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`

juju switch "<env_name>"  || { echo "ERROR While setting env <env_name> "; exit 2; }

if [ "<mms_manager_type>" = "ops" ]; then
	juju docean bootstrap -v  --constraints="mem=8G,region=<region>" || { echo "ERROR While bootstraping juju env <env_name> "; exit 2; }
	node_name="chef-server-ops-manager"
else
	juju docean bootstrap -v  --constraints="mem=2G,region=<region>" || { echo "ERROR While bootstraping juju env <env_name> "; exit 2; }
	node_name="chef-server"
fi


machine_no="0"
echo "Waiting for machine to start... (current : pending)"
sleep 1m
export machine_status="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $2}')"

while [ "$machine_status" =  "pending" ]; do
	echo "Waiting for machine to start... (current : $machine_status)"
	export	machine_status="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $2}')"
	sleep 20s

done

if [ "$machine_status" = "started" ]; then
	bootstarp_node="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')"
else
	exit 2
fi
echo "Copy install chef server script to $bootstarp_node"
juju scp $BASE_DIR/install_chef_server.sh $machine_no:/tmp/  || { echo "ERROR Copying chef server install for <env_name> env "; exit 2; }

echo "Running install script for chef server on $bootstarp_node ... Can take up to 20m0s"
juju run "sudo /tmp/install_chef_server.sh https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/trusty/chef-server-core_12.3.1-1_amd64.deb admin mongodb123  2>&1" --machine ${machine_no} --timeout "20m0s" || { echo "ERROR Bottstraping chef server install for <env_name> env "; exit 2; }

echo "Expose needed ports for chef server $bootstrap_node..."
juju deploy --repository=/root/.juju/charms/ local:trusty/deploy-node $node_name --to $machine_no 

juju expose $node_name 

sleep 50s


juju scp $machine_no:/tmp/\*.pem /root/.chef/  || { echo "ERROR Copying chef server credentials to /root/.chef/ "; exit 2; }

juju set-constraints "cpu-cores=1 mem=1G"

rm /root/.ssh/known_hosts



