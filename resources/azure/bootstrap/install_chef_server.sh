#!/bin/bash

function usage () {
	echo " ############### install_chef_server.sh ############"
	echo " Usage : ./install_chef_server.sh [installtion_file_url] [admin_user] [password] "
	echo "    	[installtion_file_url] - blob url (example : https://packagecloud.io/chef/stable/packages/ubuntu/trusty/chef-server-core_12.3.1-1_amd64.deb/download )"
	echo "       [admin_user] - Main user "
	echo "       [password] - Main user password "
}

if [ $# -lt 3 ]; then
	usage
	exit 1
fi
	

export INSTALLATION_LOG=/var/log/chef-server_install_$(date +"%m-%d-%Y--%T").log

#https://aa1202storage.blob.core.windows.net/services/chef/chef-chef-server-core_12.0.5-1_amd64.deb
CHEF_SERVER_DEB_URL=$1
ADMIN_USER=$2
PASSWORD=$3
HOST=$4

function log () {
	if [ $# -ne 0 ]; then
		local MSG="$1"
        local DATE=$(date +"%m-%d-%Y--%T") 
		echo "${DATE} :: ${MSG}" 2>&1 | tee -a ${INSTALLATION_LOG}
	else
		while read MSG; do
	        local DATE=$(date +"%m-%d-%Y--%T")
			echo "${DATE} :: ${MSG}" 2>&1 | tee -a ${INSTALLATION_LOG}
		done
	fi
}

function fatal () {
        local MSG=$1
		log "FATAL $MSG"
		exit 1
}

function configure_manage_console ()
{
	chef-server-ctl install opscode-manage || fatal "Failed to run 'chef-server-ctl install opscode-manage ' "
	opscode-manage-ctl reconfigure || fatal "Failed to run  'opscode-manage-ctl reconfigure'"
	chef-server-ctl reconfigure  || fatal "Failed to run  'chef-server-ctl reconfigure'"
}

function main () {
	
	log "Starting  installation chef-server!"
	cd /tmp
	
	if ! which chef-server-ctl 2>/dev/null ; then
		log "downloading '$CHEF_SERVER_DEB_URL' file"

		wget $CHEF_SERVER_DEB_URL || fatal "Failed to wget '$CHEF_SERVER_DEB_URL' file"

		DEB_FILE=$(ls -tr chef-server* | tail -1)
		log "Extracting and installing  '$DEB_FILE' file" 
		dpkg -i ./$DEB_FILE || fatal "Failed to extract and install  '$DEB_FILE' file" 
	fi
	log "Running chef-server-ctl reconfigure ... " 

	chef-server-ctl reconfigure || fatal "Failed to run chef-server-ctl reconfigure" 

	log "Creating main user '$ADMIN_USER' ... " 

	chef-server-ctl user-create $ADMIN_USER "Juju" "juju-deploy" "test@dummy.com" $PASSWORD --filename /tmp/$ADMIN_USER.pem || fatal "Falied to configure the main user"

	log "Creating organization 'juju-deploy' for  user '$ADMIN_USER' ... " 

	chef-server-ctl org-create "juju-deploy" "juju-deploy-test" --association_user $ADMIN_USER --filename /tmp/juju-deploy-validator.pem || fatal "Falied to configure the main organization 'juju-deploy' for user '$ADMIN_USER'"

	log "Installing Chef Manage Web UI feature.." 

	configure_manage_console
	
	HOSTNAME=$(hostname)
	
	echo "server_name = \"${HOST}\"" >> /etc/opscode/chef-server.rb
	echo "api_fqdn = server_name " >> /etc/opscode/chef-server.rb
	echo "bookshelf['vip'] = server_name " >> /etc/opscode/chef-server.rb
	echo "nginx['url'] = \"https://#{server_name}\"" >> /etc/opscode/chef-server.rb
	echo "nginx['server_name'] = server_name" >> /etc/opscode/chef-server.rb
	echo "nginx['ssl_certificate'] =  \"/var/opt/opscode/nginx/ca/#{server_name}.crt\""  >> /etc/opscode/chef-server.rb
	echo "nginx['ssl_certificate_key'] = \"/var/opt/opscode/nginx/ca/#{server_name}.key\"" >> /etc/opscode/chef-server.rb
	echo "lb['fqdn'] = server_name " >> /etc/opscode/chef-server.rb

	chef-server-ctl reconfigure || fatal "Failed to run chef-server-ctl reconfigure" 
	
	
	log "Successfuly installed chef-server!"
	echo " "
	echo "Login into https://<public_ip> with the provided $ADMIN_USER credentials and download the knife.rb of the devopshz organization "
	echo "Please find the user pem : /tmp/$ADMIN_USER.pem, and organization validator pem : /tmp/${ADMIN_USER}-validator.pem "
	echo "Place those inside your chefDK repo to start  working form more details : https://docs.chef.io/"
}

main
