#!/bin/bash

juju switch "<env_name>"  || { echo "ERROR While setting env <env_name> "; exit 2; }

juju destroy-environment "<env_name>" -y || { echo "ERROR While destroying env <env_name> "; exit 2;} 
