#!/bin/bash

FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`


echo "Populate cookbooks and roles to /root/.chef/"
cp -R $BASE_DIR/cookbooks /root/.chef/ || { echo "ERROR Populate cookbooks "; exit 2;}
cp -R $BASE_DIR/roles    /root/.chef/ || { echo "ERROR Populate cookbooks "; exit 2;}
public_ip=$(juju status --format tabular | grep "^0   .*" | awk '{print $4}')
sed -i "s#<chef-server>#${public_ip}#g" $BASE_DIR/knife_conf/knife.rb
cp -R $BASE_DIR/knife_conf/knife.rb /root/.chef/
