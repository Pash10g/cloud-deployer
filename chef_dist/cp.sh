#!/bin/bash

set -e

cp -R ./cookbooks/* ../resources/gce/deploy/db-create/chef/cookbooks/
cp -R ./roles/* ../resources/gce/deploy/db-create/chef/roles/

cp -R ./cookbooks/* ../resources/amazon/deploy/db-create/chef/cookbooks/ 
cp -R ./roles/* ../resources/amazon/deploy/db-create/chef/roles/


cp -R ./cookbooks/* ../resources/digitalocean/deploy/db-create/chef/cookbooks/
cp -R ./roles/* ../resources/digitalocean/deploy/db-create/chef/roles/

