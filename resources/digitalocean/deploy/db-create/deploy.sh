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
echo "" > /tmp/<cluster_name>-<env_name>-mongo-conf.yaml

# Loop to provision all configsvr vm's
for ((i=1; i <= <configsvr_number>; i++)) 
do

	echo "Starting deploy configsvr${i}"
	# Check if current configsvr component is already provisioned
	if [ ! $(juju status --format tabular | grep "configsvr${i}/" | awk '{print $7}') ]; then
		# Deploy configsvr VM
		deploy_vm "cpu-cores=<configsvr_cpu_core>,mem=<configsvr_mem_mb>,root-disk=<configsvr_data_disk>" machine_no
		
		# Save data
		fqdn=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
		echo "configsvr${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  replicaset : <configsvr_repl_set_name> " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  config_server_port : <configsvr_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		
		# Deploy any juju specifics to the vm (open ports, etc.)	
		juju deploy --repository=/root/.juju/charms local:trusty/deploy-node "configsvr${i}"  --to $machine_no 
		
		# Exopose the service to the outside world
		echo "Exposing configsvr${1}"
		juju expose "configsvr${i}"
		sleep 30s
	else
		echo "configsvr${i} component already exist re-bootstraping..."
		fqdn=$(juju status --format tabular | grep "configsvr${i}/" | awk '{print $7}') 
		echo "configsvr${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  replicaset : <configsvr_repl_set_name> " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  config_server_port : <configsvr_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	fi
	#Bootstrap chef configuration with role configsvr on the VM
	echo " Starting chef add node : 'role[configsvr]' on host : ${fqdn}"
	knife bootstrap  ${fqdn}  -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[configsvr]' --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine} role[configsvr]  "; exit 2; }
	echo " Successfully finished chef install 'role[configsvr]' on host : ${fqdn}"
done

# Loop to provision all mongos vm's
for ((i=1; i <= <mongos_number>; i++)) 
do
	echo " Starting deploy of mongos${i}"
	# Check if current mongos component is already provisioned
	if [ ! $(juju status --format tabular | grep "mongos${i}/" | awk '{print $7}') ]; then
		# Deploy mongos VM
	        deploy_vm "mem=<mongos_mem_mb>,cpu-cores=<mongos_cpu_core>,root-disk=<mongos_data_disk>" machine_no
		fqdn=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
	        echo "mongos${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        echo "  mongos_port : <mongos_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        echo "  ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        # Deploy any juju specifics to the vm (open ports, etc.)
		juju deploy --repository=/root/.juju/charms local:trusty/deploy-node "mongos${i}"  --to $machine_no 
	
		echo "Exposing mongos${1}"
		juju expose "mongos${i}"
		sleep 30s
		
	else
		
		echo "mongos${i} component already exist re-bootstraping..."
		fqdn=$(juju status --format tabular | grep "mongos${i}/" | awk '{print $7}') 
		echo "mongos${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        echo "  mongos_port : <mongos_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	        echo "  ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	fi
	#Bootstrap chef configuration with role mongos on the VM
	echo " Starting chef add node : 'role[mongos]' on host : ${fqdn}"
        knife bootstrap  $fqdn  -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[mongos]' --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine_mongos} role[mongos]  "; exit 2; }
	echo " Successfully finished chef install 'role[mongos]' on host : ${fqdn}"
done


for ((i=1; i <= <shard_number>; i++)) 
do

	echo " Starting deploy of shard${i}"
	# Check if current shard component is already provisioned
	if [ ! $(juju status --format tabular | grep "shard${i}/" | awk '{print $7}') ]; then
		# Deploy shard VM
		deploy_vm "mem=<shard_mem_mb>,cpu-cores=<shard_cpu_core>,root-disk=<shard_data_disk>" machine_no
		fqdn=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
		echo "shard${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  shard_replica_set_name : <shard_repl_set_name>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  shard_port : <shard_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		juju deploy --repository=/root/.juju/charms local:trusty/deploy-node "shard${i}"  --to $machine_no 
	
		echo "Exposing shard${i}"
		juju expose "shard${i}"
		sleep 30s
	else
		echo "shard${i} component already exist re-bootstraping..."
		fqdn=$(juju status --format tabular | grep "shard${i}/" | awk '{print $7}') 
		echo "shard${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  shard_replica_set_name : <shard_repl_set_name>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  shard_port : <shard_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "  ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	fi
	#Bootstrap chef configuration with role shard on the VM providing relevant configuration
	echo " Starting chef add node : 'role[shard]' on host : ${fqdn}"	
        knife bootstrap  ${fqdn}  -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[shard]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_shard${i}\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine_shard} role[shard]  "; exit 2; }
	echo " Successfully finished chef install 'role[shard]'  on host : ${fqdn}"
	
	for ((j=1; j <= <shard_repl_number>; j++))
	do
		echo " Starting deploy of shard${i}-replicaset${j}"
		# Check if current replicaset component is already provisioned
		if [ ! $(juju status --format tabular | grep "shard${i}-replicaset${j}/" | awk '{print $7}') ]; then
			# Deploy replicaset VM
			deploy_vm "mem=<shard_mem_mb>,cpu-cores=<shard_cpu_core>,root-disk=<shard_data_disk>" machine_no
			fqdn=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
			echo "  shard-replicaset${j}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	 		echo "    shard_replica_set_name : <shard_repl_set_name>_shard${i}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			echo "    shard_replicaset_port : <shard_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			echo "    machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			echo "    ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			juju deploy --repository=/root/.juju/charms local:trusty/deploy-node  "shard${i}-replicaset${j}"  --to $machine_no 
	
			echo "Exposing  shard${i}-replicaset${j}"
			juju expose "shard${i}-replicaset${j}"
			sleep 30s
		else
			echo "shard${i}-replicaset${j} component already exist re-bootstraping..."
			fqdn=$(juju status --format tabular | grep "shard${i}-replicaset${j}/" | awk '{print $7}') 
			echo "  shard-replicaset${j}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	 		echo "    shard_replica_set_name : <shard_repl_set_name>_shard${i}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			echo "    shard_replicaset_port : <shard_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			echo "    machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
			echo "    ip address: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		fi
		#Bootstrap chef configuration with role replicaset on the VM providing relevant configuration
		echo " Starting chef add node : 'role[replicaset]' on host : ${fqdn}"	
		knife bootstrap  ${fqdn}  -i /root/.juju/ssh/juju_id_rsa --ssh-user ubuntu --sudo -r 'role[replicaset]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_shard${i}\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${fqdn} role[replicaset]  "; exit 2; }

		echo " Successfully finished chef install 'role[replicaset]'  on host : ${fqdn}"
	done
done


echo "########################################################################"
echo "# Cluster deployment is finished ! "
echo "# For deployed cluster info please see /tmp/<cluster_name>-<env_name>-mongo-conf.yaml "
echo "# or run : juju status"
echo "########################################################################"
