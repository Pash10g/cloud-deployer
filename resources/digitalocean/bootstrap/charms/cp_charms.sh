#!/bin/bash
set -e

FULLPATH_SCRIPT=`readlink -f "$0"`
export BASE_DIR=`dirname $FULLPATH_SCRIPT`


echo "Populate charms  to /root/.chef/"
cp -R $BASE_DIR/charms /root/.juju/ || { echo "ERROR Populate charms "; exit 2;}
