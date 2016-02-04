#!/bin/bash

set -e

FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`

juju switch "<env_name>"  || { echo "ERROR While setting env <env_name> "; exit 2; }
if [ "<mms_manager_type>" = "ops" ]; then
	constraints="cpu-cores=2 cpu-power=0  mem=4G "
else
	constraints="cpu-cores=1 cpu-power=0  mem=2G "
fi

juju bootstrap -v  --constraints $constraints || { echo "ERROR While bootstraping juju env <env_name> "; exit 2; }

machine_no="0"
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
juju deploy --repository=/root/.juju/charms/ local:trusty/deploy-node chef-server  --to $machine_no 

juju expose chef-server

sleep 50s


juju scp $machine_no:/tmp/\*.pem /root/.chef/  || { echo "ERROR Copying chef server credentials to /root/.chef/ "; exit 2; }

juju set-constraints "cpu-cores=1 cpu-power=0  mem=1G"

rm /root/.ssh/known_hosts

if [ "<mms_manager_type>" = "ops" ]; then
	
	# Set chef org
	export CHEF_ORGNAME="juju-deploy"

	# Upload chef code to the chef server
	echo "chef ssl check"
	knife ssl fetch || { echo "ERROR While chef ssl fetch "; exit 2; }
	knife ssl check || { echo "ERROR While chef check fetch "; exit 2; }
	back_dir=`pwd`
	echo "Chef cookbooks upload..."
	cd /root/.chef/
	knife cookbook upload --all || { echo "ERROR While chef upload cookbooks"; exit 2; }
	knife upload roles ||  { echo "ERROR While chef upload roles"; exit 2; }
	cd $back_dir
	
	echo "Expose needed ports for chef server $bootstrap_node..."
	juju deploy --repository=/root/.juju/charms/ local:trusty/deploy-node ops-manager  --to $machine_no 
	
	#Bootstrap chef configuration with role configsvr on the VM
	echo " Starting chef add node : 'role[opsmanager]' on host : ${bootstarp_node}"
	knife bootstrap  ${bootstarp_node} -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[opsmanager]' --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine} role[configsvr]  "; exit 2; }
	echo " Successfully finished chef install 'role[opsmanager]' on host : ${bootstarp_node}"
	
	
fi 




