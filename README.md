# cloud-deployer
This project deploys mongodb  clusters on several supported clouds using JujuCharms and Chef technologies.

# Introduction

The project is build on both python and bash capabilities to perform mongodb cluster deployment cross several supported vendors (Currently Google Cloud, AWS, Azure, Digital ocean).
It utilizes juju and chef technologies in order to deploy and configure the machines accross several clouds.

Currently the workstation that runs the client side can be only Ubuntu (OS X is on the way).

#Usage :
The main directory has a main run file called : run_deployer.py.

./run_deployer.py [-h] [-m MODE ] -s STEP -C CLOUD.

The cloud is one of the supported clouds :
- amazon - AWS (see : https://jujucharms.com/docs/stable/config-aws for input configuration)
  * Mandatory params which should be set in config/amazon/properties.conf are :
  - ACCES_KEY (your aws access key)
  - SECRET_KEY (your aws secret key)
- gce - Google Cloud (see : https://jujucharms.com/docs/stable/config-gce for input configuration)
  * Mandatory params which should be set in config/gce/properties.conf are :
  - AUTH_FILE (Json file dowloaded from GCE Api console as stated in the manual )
    * format : {
   "type": "service_account",
   "private_key_id": "xxxxxxxxxxxxxxxxx",
   "private_key": "-----BEGIN PRIVATE KEY-----\nxxxxxxxx\n-----END PRIVATE KEY-----\n",
   "client_email": "xxxxx@xxxxxx.iam.gserviceaccount.com",
   "client_id": "xxxxxxxxxxxxxx"
   }
  - PROJECT_ID (Google GCE project_id you would like to use)
- azure - Azure cloud (see https://jujucharms.com/docs/stable/config-azure)
  * Mandatory params which should be set in config/azure/properties.conf are :
  - MANAGEMENT_CERTIFICATE_PATH (Certificate full path name of azure.pem from which azure.crt were uploaded [as stated in the manual] )
  - STORAGE_ACCOUNT_NAME (azure storage  account name [must be the same region as "REGION" value] )
  - SUBSCRIPTION_ID ( azure subscritption id)
- digitalocean - Digital ocean cloud  (see  https://jujucharms.com/docs/stable/config-digitalocean)
 * Mandatory params which should be set in config/digitalocean/properties.conf are :
 - AC_KEY  ( Digital ocean oath key from the API configuration)
 - SSH_KEY_NAME (ssh public key name provided after upload  to digital ocean console  [ found under /root/.juju/ssh/juju_id_rsa.pub ])
  
The steps :
- init-bootstrap - lunches juju and chef server on the desired cloud.
- deploy - deploys the mongodb cluster [ if the nodes are present it reconfigures them and adds any additional members of the cluster if expanded ]
- deploy-standalone - deploys mongodb stand alone instance [ uses "SHARD_*" configuration and intiates replicas if stated]
- destroy-env - drops all machines and services from the environment


The mode : 
- x  - using a property file located under config/\<vendor\>/properties.conf
   * each file has the default values and the Mandatory values that needs to be provided (mandatory are account oriented)
- i - interactive mode where user input needed for all properties required

Not specifiying mode means that you need to specify any needed input  via ENVIRONMENT VARAIBLES (see config/\<vendor\>/properties.conf for the list)

# Quick Start
 On your ubuntu host git clone the project .
 go to cloud-deployer/

Make sure that all files are executable and you have sudo permissions .

gce Example:
- place all needed info in the properties file 

Run : ./run_deployer.py -m x -s init-bootstrap -c gce

Run : ./run_deployer.py -m x -s deploy -c gce

To delete env:

Run : ./run_deployer.py -m x -s destroy-env -c gce


Thats it!

