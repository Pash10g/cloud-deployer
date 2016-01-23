#!/bin/bash

set -e

function deploy_vm {
	constraints=$1
	echo " Lunching machine  constraints : ${constraints}"
	export machine_no=$(juju machine add --constraints "$constraints cpu-power=0" 2>&1 | awk '{print $3}') #|| {echo "failed to init machine constraints $constraints "; exit 2}
	echo "Machine successfuly lunched , machine-no : ${machine_no} "
	sleep 1m
	export machine_status="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $2}')"
	while [ "$machine_status" =  "pending" ]; do
		echo "Waiting for machine to start... (current : $machine_status)"
		export  machine_status="$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $2}')"
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

back_dir=`pwd`
echo "Chef cookbooks upload..."
cd /root/.chef/
knife cookbook upload --all || { echo "ERROR While chef upload cookbooks"; exit 2; }
knife upload roles ||  { echo "ERROR While chef upload roles"; exit 2; }
cd $back_dir

echo "" > /tmp/standalone-<env_name>-mongo-conf.yaml

echo " Starting deploy of primary"
if [ ! $(juju status --format tabular | grep "primary/" | awk '{print $7}') ]; then
	deploy_vm "mem=<shard_mem_mb> cpu-cores=<shard_cpu_core> root-disk=<shard_data_disk>" machine_no
	machine_primary=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
	fqdn=$(juju status --format tabular | grep ${machine_primary} | awk '{print $3}')
	echo "primary: " >> /tmp/standalone-<env_name>-mongo-conf.yaml
	echo "  primary_replica_set_name : <shard_repl_set_name>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
	echo "  primary_port : <shard_port>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
	echo "  machine: machine-${machine_no}" >> /tmp/standalone-<env_name>-mongo-conf.yaml
	echo "  FQDN: ${fqdn} " >> /tmp/standalone-<env_name>-mongo-conf.yaml
	juju deploy /root/.juju/charms/trusty/deploy-node "primary" --series trusty --to $machine_no 

	echo "Exposing primary"
	juju expose "primary"
	sleep 30s
else
	echo "primary component already exist re-bootstraping..."
	fqdn=$(juju status --format tabular | grep "primary/" | awk '{print $7}') 
fi	
echo " Starting chef add node : 'role[shard]' on host : ${fqdn}"	
knife bootstrap  ${fqdn} --ssh-user ubuntu --sudo -r 'role[shard]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_primary\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${machine_primary} role[shard]  "; exit 2; }
echo " Successfully finished chef install 'role[shard]'  on host : ${fqdn}"

for j in {1..<shard_repl_number>} 
do
	echo " Starting deploy of primary-replicaset${j}"
	if [ ! $(juju status --format tabular | grep "primary-replicaset${j}/" | awk '{print $7}') ]; then
		deploy_vm "mem=<shard_mem_mb> cpu-cores=<shard_cpu_core> root-disk=<shard_data_disk>" machine_no
		machine_repl=$(juju status --format tabular | grep "^${machine_no} .*" | awk '{print $4}')
		fqdn=$(juju status --format tabular | grep ${machine_repl} | awk '{print $3}')
		echo "  primary-replicaset${j}: " >> /tmp/standalone-<env_name>-mongo-conf.yaml
 		echo "    primary_replica_set_name : <shard_repl_set_name>_primary" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "    primary_replicaset_port : <shard_port>" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "    machine: machine-${machine_no}" >> /tmp/standalone-<env_name>-mongo-conf.yaml
		echo "    FQDN: ${fqdn} " >> /tmp/standalone-<env_name>-mongo-conf.yaml
		juju deploy /root/.juju/charms/trusty/deploy-node "primary-replicaset${j}" --series trusty --to $machine_no 

		echo "Exposing  primary-replicaset${j}"
		juju expose "primary-replicaset${j}"
		sleep 30s
	else
		echo "primary-replicaset${j} component already exist re-bootstraping..."
		fqdn=$(juju status --format tabular | grep "primary-replicaset${j}/" | awk '{print $7}') 
	fi
	echo " Starting chef add node : 'role[replicaset]' on host : ${fqdn}"	
	knife bootstrap  ${fqdn} --ssh-user ubuntu --sudo -r 'role[replicaset]' -j "{ \"mongodb3\" : { \"config\" : { \"mongod\" : {  \"replication\" : {  \"replSetName\" : \"<shard_repl_set_name>_primary\" } } } } }" --bootstrap-install-command 'curl -L https://www.chef.io/chef/install.sh | sudo bash' || { echo "Failed to bootstrap machine : ${fqdn} role[replicaset]  "; exit 2; }

	echo " Successfully finished chef install 'role[replicaset]'  on host : ${fqdn}"
done


echo "########################################################################"
echo "# For deployed standalone mongodb info please see /tmp/standalone-<env_name>-mongo-conf.yaml "
echo "# or run : juju status"
echo "########################################################################"
