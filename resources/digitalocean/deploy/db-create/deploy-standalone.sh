#!/bin/bash
####################
##
## This code is deploying a sharded mongodb cluster using juju and chef commands
## There are three phases : 1. Configsvr deployment 2. Mongos deployment 3. Shards and replicasets 
##
####################
set -e

## Deploy vm function
function deploy_vm {
	# Recieve vm constraints (characteristics) and provision it
	constraints=$1
	echo " Lunching machine  constraints : ${constraints}"
	export machine_no=$(juju docean add-machine  --constraints="$constraints" 2>&1 | grep 'mid:' | cut -d " " -f 7 ) #|| {echo "failed to init machine constraints $constraints "; exit 2}
	echo "Machine successfuly lunched , machine-no : ${machine_no} "
	sleep 1m
	# Check provision status
	export machine_status="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $2}')"
	while [ "$machine_status" =  "pending" ]; do
		echo "Waiting for machine to start... (current : $machine_status)"
		export  machine_status="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $2}')"
        	sleep 20s
	done
	
	# See if provision succeded 
	if [ "$machine_status" = "started" ]; then
                #juju run "uname -a" --machine ${machine_no}
        	eval "$2=$machine_no"
	else
		echo "Provision of vm no : ${machine_no} failed , status : $machine_status"
        	exit 2
	fi
}

# Set current script location
FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`

source ~/.bashrc

# Set juju env
juju switch "<env_name>"  || { echo "ERROR While setting env <env_name> "; exit 2; }

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

# Set output yaml to none
echo "" > /tmp/standalone-<env_name>-mongo-conf.yaml



	echo " Starting deploy of primary"
	# Check if current shard component is already provisioned
	if [ ! $(juju status --format tabular | grep "primary/" | awk '{print $7}') ]; then
		# Deploy shard VM
		deploy_vm "mem=<shard_mem_mb>,cpu-cores=<shard_cpu_core>,root-disk=<shard_data_disk>" machine_no
		fqdn=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
		echo "primary: " >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  shard_replica_set_name : <shard_repl_set_name>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  shard_port : <shard_port>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  machine: machine-${machine_no}" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  FQDN: ${fqdn} " >> /tmp/standalone-<env_name>-mongo-conf.yaml
		juju deploy --repository=/root/.juju/charms local:trusty/deploy-node /root/.juju/charms/trusty/deploy-node "primary" --to $machine_no 
	
		echo "Exposing primary"
		juju expose "primary"
		sleep 30s
	else
		echo "primary component already exist re-bootstraping..."
		fqdn=$(juju status --format tabular | grep "primary/" | awk '{print $7}') 
		echo "primary: " >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  shard_replica_set_name : <shard_repl_set_name>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  shard_port : <shard_port>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  machine: machine-${machine_no}" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "  FQDN: ${fqdn} " >> /tmp/standalone-<env_name>-mongo-conf.yaml
	fi
	#Bootstrap chef configuration with role shard on the VM providing relevant configuration
	echo " Starting chef add node : 'role[shard]' on host : ${fqdn}"	
        knife bootstrap  ${fqdn}  -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[shard]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_primary\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine_shard} role[shard]  "; exit 2; }
	echo " Successfully finished chef install 'role[shard]'  on host : ${fqdn}"
	
	for ((j=1; j <= <shard_repl_number>; j++))
	do
		echo " Starting deploy of primary-replicaset${j}"
		# Check if current replicaset component is already provisioned
		if [ ! $(juju status --format tabular | grep "primary-replicaset${j}/" | awk '{print $7}') ]; then
			# Deploy replicaset VM
			deploy_vm "mem=<shard_mem_mb>,cpu-cores=<shard_cpu_core>,root-disk=<shard_data_disk>" machine_no
			fqdn=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
			echo "  shard-replicaset${j}: " >> /tmp/standalone-<env_name>-mongo-conf.yaml
	 		echo "    shard_replica_set_name : <shard_repl_set_name>_primary" >> /tmp/standalone-<env_name>-mongo-conf.yaml
			echo "    shard_replicaset_port : <shard_port>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
			echo "    machine: machine-${machine_no}" >> /tmp/standalone-<env_name>-mongo-conf.yaml
			echo "    FQDN: ${fqdn} " >> /tmp/standalone-<env_name>-mongo-conf.yaml
			juju deploy --repository=/root/.juju/charms local:trusty/deploy-node "primary-replicaset${j}"  --to $machine_no 
	
			echo "Exposing  primary-replicaset${j}"
			juju expose "primary-replicaset${j}"
			sleep 30s
		else
			echo "primary-replicaset${j} component already exist re-bootstraping..."
			fqdn=$(juju status --format tabular | grep "primary-replicaset${j}/" | awk '{print $7}') 
			echo "  shard-replicaset${j}: " >> /tmp/standalone-<env_name>-mongo-conf.yaml
	 		echo "    shard_replica_set_name : <shard_repl_set_name>_primary" >> /tmp/standalone-<env_name>-mongo-conf.yaml
			echo "    shard_replicaset_port : <shard_port>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
			echo "    machine: machine-${machine_no}" >> /tmp/standalone-<env_name>-mongo-conf.yaml
			echo "    FQDN: ${fqdn} " >> /tmp/standalone-<env_name>-mongo-conf.yaml
		fi
		#Bootstrap chef configuration with role replicaset on the VM providing relevant configuration
		echo " Starting chef add node : 'role[replicaset]' on host : ${fqdn}"	
		knife bootstrap  ${fqdn}  -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[replicaset]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_primary\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${fqdn} role[replicaset]  "; exit 2; }

		echo " Successfully finished chef install 'role[replicaset]'  on host : ${fqdn}"
	done
done


echo "########################################################################"
echo "# Cluster deployment is finished ! "
echo "# For deployed cluster info please see /tmp/standalone-<env_name>-mongo-conf.yaml "
echo "# or run : juju status"
echo "########################################################################"
