#!/bin/bash

juju switch "<env_name>" || { echo "ERROR While setting env <env_name> "; exit 2; }

juju expose mongos  || { echo "Failed to expose mongodb mongos "; exit 2; }

for i in {1..<configsvr_number>}
do
	juju expose "configsvr${i}"  || { echo "Failed to expose mongodb configsvr${i}  "; exit 2; }
done

for i in {1..<shard_number>} 
do
	juju expose "shard${i}"  || { echo "Failed to expose mongodb shard${i}"; exit 2; }
done
sleep 1m
