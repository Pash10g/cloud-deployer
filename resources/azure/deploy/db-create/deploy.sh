#!/bin/bash

set -e

function deploy_vm {
	constraints=$1
	echo " Lunching machine  constraints : ${constraints}"
	export machine_no=$(juju machine add --constraints "$constraints" 2>&1 | awk '{print $3}') #|| {echo "failed to init machine constraints $constraints "; exit 2}
	echo "Machine successfuly lunched , machine-no : ${machine_no} "
	sleep 1m
	export machine_status="$(juju status --format tabular | grep machine-${machine_no} | awk '{print $2}')"
	while [ "$machine_status" =  "pending" ]; do
		echo "Waiting for machine to start... (current : $machine_status)"
		export  machine_status="$(juju status --format tabular | grep machine-$machine_no | awk '{print $2}')"
        	sleep 20s
	done
	if [ "$machine_status" = "started" ]; then
                juju run "uname -a" --machine ${machine_no}
        	eval "$2=$machine_no"
	else
        	exit 2
	fi
}


FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`

juju switch "<env_name>"  || { echo "ERROR While setting env <env_name> "; exit 2; }

export CHEF_ORGNAME="juju-deploy"

echo "chef ssl check"
knife ssl fetch || { echo "ERROR While chef ssl fetch "; exit 2; }
knife ssl check || { echo "ERROR While chef check fetch "; exit 2; }

echo "Chef cookbooks upload..."
cd /root/.chef/
back_dir=`pwd`
knife cookbook upload --all || { echo "ERROR While chef upload cookbooks"; exit 2; }
knife upload roles ||  { echo "ERROR While chef upload roles"; exit 2; }
cd $back_dir

echo "" > /tmp/<cluster_name>-<env_name>-mongo-conf.yaml

for i in {1..<configsvr_number>}
do

	echo "Starting deploy configsvr${i}"
	deploy_vm "mem=<configsvr_mem_mb> cpu-cores=<configsvr_cpu_core>"  machine_no
	fqdn=$(juju status --format tabular | grep machine-${machine_no} | awk '{print $3}')
	echo "configsvr${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  replicaset : <configsvr_repl_name> " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  config_server_port : <configsvr_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  FQDN: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	
	juju deploy /root/.juju/charms/trusty/deploy-node "configsvr${i}" --series trusty --to $machine_no 

	echo "Exposing configsvr${i}"
	juju expose "configsvr${i}"
	sleep 30s
	echo " Starting chef add node : 'role[configsvr]' on host : ${fqdn}"
	knife bootstrap  ${fqdn}  --ssh-user ubuntu --sudo -r 'role[configsvr]' --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine} role[configsvr]  "; exit 2; }
	
	echo " Successfully finished chef install 'role[configsvr]' on host : ${fqdn}"
done



for i in {1..<mongos_number>} 
do
	echo " Starting deploy of mongos${i}"
        deploy_vm "mem=<mongos_mem_mb> cpu-cores=<mongos_cpu_core>" machine_no
		fqdn=$(juju status --format tabular | grep machine-${machine_no} | awk '{print $3}')
        echo "mongos${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
        echo "  mongos_port : <mongos_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
        echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
        echo "  FQDN: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		juju deploy /root/.juju/charms/trusty/deploy-node "mongos${i}" --series trusty --to $machine_no 
	
		echo "Exposing mongos${i}"
		juju expose "mongos${i}"
		sleep 30s
	echo " Starting chef add node : 'role[mongos]' on host : ${fqdn}"
        knife bootstrap  $fqdn  --ssh-user ubuntu --sudo -r 'role[mongos]' --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${fqdn} role[mongos]  "; exit 2; }

	echo " Successfully finished chef install 'role[mongos]' on host : ${fqdn}"
done



for i in {1..<shard_number>} 
do
	
	echo " Starting deploy of shard${i}"
	deploy_vm "mem=<shard_mem_mb> cpu-cores=<shard_cpu_core>" machine_no
	fqdn=$(juju status --format tabular | grep machine-${machine_no} | awk '{print $3}')
	 echo "shard${i}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	 echo "  shard_replica_set_name : <shard_repl_set_name>_shard${i}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  shard_port : <shard_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	echo "  FQDN: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
	juju deploy /root/.juju/charms/trusty/deploy-node "shard${i}" --series trusty --to $machine_no 

	echo "Exposing shard${i}"
	juju expose "shard${i}"
	sleep 30s
	echo " Starting chef add node : 'role[shard]' on host : ${fqdn}"	
	 knife bootstrap  ${fqdn} --ssh-user ubuntu --sudo -r 'role[shard]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_shard${i}\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${fqdn} role[shard]  "; exit 2; }

	echo " Successfully finished chef install 'role[shard]'  on host : ${fqdn}"
	for j in {1..<shard_repl_number>} 
	do
		echo " Starting deploy of shard${i}-replicaset${j}"
		deploy_vm "mem=<shard_mem_mb> cpu-cores=<shard_cpu_core>" machine_no
		fqdn=$(juju status --format tabular | grep machine-${machine_no} | awk '{print $3}')
		echo "  shard-replicaset${j}: " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
 		echo "    shard_replica_set_name : <shard_repl_set_name>_shard${i}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "    shard_replicaset_port : <shard_port>" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "    machine: machine-${machine_no}" >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		echo "    FQDN: ${fqdn} " >> /tmp/<cluster_name>-<env_name>-mongo-conf.yaml
		juju deploy /root/.juju/charms/trusty/deploy-node "shard${i}-replicaset${j}" --series trusty --to $machine_no 

		echo "Exposing  shard${i}-replicaset${j}"
		juju expose "shard${i}-replicaset${j}"
		sleep 30s
		echo " Starting chef add node : 'role[replicaset]' on host : ${fqdn}"	
		knife bootstrap  ${fqdn} --ssh-user ubuntu --sudo -r 'role[replicaset]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_shard${i}\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${fqdn} role[replicaset]  "; exit 2; }

		echo " Successfully finished chef install 'role[replicaset]'  on host : ${fqdn}"
	done
done

echo "########################################################################"
echo "# For deployed cluster info please see /tmp/<cluster_name>-<env_name>-mongo-conf.yaml "
echo "# or run : juju status"
echo "########################################################################"
