# properties.conf file

# Mandatory Values
ACCESS_KEY - AWS Access key obtained for "Security Credentials" tab
SECRET_KEY - AWS Secret key obtained for "Security Credentials" tab

# Default Values
REGION=us-east-1 - AWS Region 
CLUSTER_NAME=test - Cluster identifier for deployment (currently only 1 per env)
ENV_NAME=amazon - Juju env name to be managed , used when init-bootstrap , deploy, deploy-standalone , destroy-env
DIST_VERSION=3.2 - Mongo distrebution major version (3.0 , 3.1, 3.2)
MONGO_VERSION=3.2.0 MongoDB version , must be aligned with the "DIST_VERSION" of course
CONFIGSVR_REPL_SET_NAME=configrpl - Config server replica set prefix (if applicable)
CONFIGSVR_REPL_SET_NUMBER=1 - Deprycated param
CONFIGSVR_NUMBER=3 - Number of config servers
CONFIGSVR_CPU_CORE=1 - Number of config servers for each machine
CONFIGSVR_MEM_MB=1G - The memory characteristics for each config server machine
CONFIGSVR_DATA_DISK=10G - Amount of disk for mongodb data
CONFIGSVR_JOURNAL_DISK=10G - Amount of disk for mongodb journal
CONFIGSVR_PORT=27019 - Port for each confi server instance
MONGOS_NUMBER=1 - Number of mongos machines
MONGOS_CPU_CORE=1
MONGOS_MEM_MB=1G
MONGOS_DATA_DISK=10G
MONGOS_JOURNAL_DISK=5G
MONGOS_PORT=27018
SHARD_NUMBER=2
SHARD_REPL_SET_NAME=shardrpl
SHARD_REPL_SET_NUMBER=1
SHARD_REPL_NUMBER=0
SHARD_CPU_CORE=1
SHARD_MEM_MB=1G
SHARD_DATA_DISK=30G
SHARD_JOURNAL_DISK=10G
SHARD_PORT=27017
SYSTEM_NAME=dummy
SYSTEM_PASSWORD=dummy
MMS_MANAGER_TYPE=cloud
\# Relevant only if MMS_MANAGER_TYPE is ops
MMS_MANAGER_VERSION=2.0.1.332-1
MMS_API_KEY=none
MMS_GROUP_ID=none
