#!/bin/bash
if [ -z $1 ]; then
	echo "Usage add-vm.sh constraints-caluse (eg. 'cpu-cores=1 mem=2G' )"
	exit 1
fi

constraints=$1

export machine_no=$(juju machine add --constraints $constraints 2>&1 | awk '{print $3}') #|| {echo "failed to init machine constraints $constraints "; exit 2}
#machine_no="13"
sleep 1m
export machine_status="$(juju status --format tabular | grep machine-${machine_no} | awk '{print $2}')"

while [ "$machine_status" =  "pending" ]; do
#	echo "Waiting for machine to start... (current : $machine_status)"
export	machine_status="$(juju status --format tabular | grep machine-$machine_no | awk '{print $2}')"
	sleep 20s

done

if [ "$machine_status" = "started" ]; then
	echo "machine-$machine_no"
	exit 0
else
	exit 2
fi

