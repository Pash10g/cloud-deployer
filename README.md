# cloud-deployer
This project deploys mongodb  clusters on several supported clouds using JujuCharms and Chef technologies.

# Introduction

The project is build on both python and bash capabilities to perform mongodb cluster deployment cross several supported vendors (Currently Google Cloud and AWS).
It utilizes juju and chef technologies in order to deploy and configure the machines accross several clouds.

Currently the workstation that runs the client side can be only Ubuntu (OS X is on the way).

#Usage :
the main directory has a main run file called : run_deployer.py.

./run_deployer.py [-h] [-m MODE ] -s STEP -V VENDOR.

The vendors is one of the supported vnedors :
amazon - AWS
gce - Google Cloud

The steps :
- init-bootstrap - lunches juju and chef server on the desired cloud.
- deploy - deploys the mongodb cluster
- destroy-env - drops all machines and services from the environment
- add-shard - adds shard and its replicas to an exisiting cluster.

The mode : 
- x  - using a property file located under config/<vendor>/properties.conf
   * each file has the default values and the Mandatory values that needs to be provided (most of them are account oriented)
- i - interactive mode where user input for all properties required

Not specifiying mode means that you need to specify any needed input  via ENVIRONMENT VARAIBLES (see config/<vendor>/properties.conf for the list)

# Quick Start
On your ubuntu host git clone the project .
go to cloud-deployer/

Make sure that all files are executable and you have sudo permissions .

gce Example:
- place all needed info in the properties file (For more info see : https://jujucharms.com/docs/stable/config-gce)

Run : ./run_deployer.py -m x -s init-bootstrap -v gce

Run : ./run_deployer.py -m x -s deploy -v gce

To delete env:

Run : ./run_deployer.py -m x -s destroy-env -v gce


Thats it!

