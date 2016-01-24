#!/bin/bash
set -e

juju switch "<env_name>"  || { echo "ERROR While setting env <env_name> "; exit 2; }

juju destroy-environment "<env_name>" -y || { echo "Using destroy-controller"; juju destroy-controller "<env_name>" -y ; }

