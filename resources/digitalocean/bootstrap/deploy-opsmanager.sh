#!/bin/bash

set -e

FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`


if [ "<mms_manager_type>" = "ops" ]; then
	
	# Set chef org
	export CHEF_ORGNAME="juju-deploy"
        machine_no=0


	bootstarp_node="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')"
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
	
	#Bootstrap chef configuration with role configsvr on the VM
	echo " Starting chef add node : 'role[opsmanager]' on host : ${bootstarp_node}"
	knife bootstrap  ${bootstarp_node}  --ssh-user root --sudo -r 'role[opsmanager]' --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${bootstrap_node} role[opsmanager]  "; exit 2; }
	echo " Successfully finished chef install 'role[opsmanager]' on host : ${bootstarp_node}"
else
	echo "Ops manager deployment skipped using <mms_manager_type> insted..."
	
fi 
