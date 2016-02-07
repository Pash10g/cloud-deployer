# properties.conf file

# Mandatory Values

- AUTH_FILE - The full path to the json authfile retrieved from cloud.google.com API management section - see the correct edited format at main README
- PROJECT_ID - Project ID retrieved from cloud.google.com

# Default values
- REGION=us-east1 - GCE region
- CLUSTER_NAME=test - Cluster identifier for deployment (currently only 1 per env)
- ENV_NAME=azure - Juju env name to be managed , used when init-bootstrap , deploy, deploy-standalone , destroy-env
- DIST_VERSION=3.2 - Mongo distrebution major version (3.0 , 3.1, 3.2)
- MONGO_VERSION=3.2.0 - MongoDB version , must be aligned with the "DIST_VERSION" of course
- \# values : org or enterprise
- MONGO_DIST=org - Mongodb distrebution type , can be "org" or "enterprise"
- CONFIGSVR_REPL_SET_NAME=configrpl - Config server replica set prefix (if applicable)
- CONFIGSVR_REPL_SET_NUMBER=1 - Deprycated param
- CONFIGSVR_NUMBER=3 - Number of config servers
- CONFIGSVR_CPU_CORE=1 - Number of config servers for each machine
- CONFIGSVR_MEM_MB=1G - The memory characteristics for each config server machine
- CONFIGSVR_DATA_DISK=10G - Amount of disk for mongodb data
- CONFIGSVR_JOURNAL_DISK=10G - Amount of disk for mongodb journal
- CONFIGSVR_PORT=27019 - Port for each confi server instance
- MONGOS_NUMBER=1 - Number of mongos machines to be deployed
- MONGOS_CPU_CORE=1 - Mongos CPU corss
- MONGOS_MEM_MB=1G - Mongos memory 
- MONGOS_DATA_DISK=10G - Mongos disk per server
- MONGOS_JOURNAL_DISK=5G 
- MONGOS_PORT=27018 - Mongos server port
- SHARD_NUMBER=2 - Number of shards to be deployed
- SHARD_REPL_SET_NAME=shardrpl - Replica set name prefix
- SHARD_REPL_SET_NUMBER=1 -deprecated param
- SHARD_REPL_NUMBER= - Number of replicas for each shard or a standalone primary (if deploy-standalone is used)
- SHARD_CPU_CORE=1 - Shard CPU core number ,also used for a standalone instances
- SHARD_MEM_MB=1G - Shard memory  ,also used for a standalone instances
- SHARD_DATA_DISK=30G - Shard data disk size ,also used for a standalone instances
- SHARD_JOURNAL_DISK=10G - Shard journal disk size,also used for a standalone instances
- SHARD_PORT=27017 - Shard port
- SYSTEM_NAME=dummy -Admin user, feature use
- SYSTEM_PASSWORD=dummy -Admin user, feature use
- MMS_MANAGER_TYPE=cloud - Ops manager type : 
     * cloud : will connect deployment to cloud.mongoDB.com, 
     * ops : will deploy ops manager during init-bootstrap phase on the management server (chef-server-ops-manager).
- \# Relevant only if MMS_MANAGER_TYPE is ops
- MMS_MANAGER_VERSION=2.0.1.332-1 - MMS servet version if ops type is usef
- MMS_API_KEY=none - MMS api key retrived from MMS cloud or ops manager
- MMS_GROUP_ID=none - MMS group id retrieved from MMS cloud or ops manager
