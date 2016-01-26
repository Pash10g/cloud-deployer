#!/bin/bash

FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`


echo "Populate cookbooks and roles to /root/.chef/"
if [ "<mms_api_key>" != "none" ]; then
  sed -i "s#<mms-recipe>#,\"recipe[mongodb3::mms_monitoring_agent]\"#g" $BASE_DIR/roles/*
else
  sed -i "s#<mms-recipe>##g" $BASE_DIR/roles/*
fi
cp -R $BASE_DIR/cookbooks /root/.chef/ || { echo "ERROR Populate cookbooks "; exit 2;}
cp -R $BASE_DIR/roles    /root/.chef/ || { echo "ERROR Populate cookbooks "; exit 2;}

# Query the machine details of the chef-server
public_ip=$(juju status --format tabular | grep "machine-0" | awk '{print $5}')
sed -i "s#<chef-server>#${public_ip}#g" $BASE_DIR/knife_conf/knife.rb 
cp -R $BASE_DIR/knife_conf/knife.rb /root/.chef/

