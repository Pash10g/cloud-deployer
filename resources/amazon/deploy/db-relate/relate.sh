for i in {1..<configsvr_number>}
do
	juju add-relation mongos:mongos-cfg "configsvr${i}:configsvr" || { echo "Failed to  add-relation mongos:mongos-cfg configsvr${i}:configsvr "; exit 2; }
	sleep 20
done

for i in {1..<shard_number>} 
do
	juju add-relation mongos:mongos "shard${i}:database" || { echo "Failed to  add-relation ongos:mongos shard${i}:database"; exit 2; }
	sleep 20
done
