#
# Cookbook Name:: mongodb3
# Recipe:: default
#
# Copyright 2015, Sunggun Yu
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'mongodb3::package_repo'

# Install Mongos package
install_package = %w(mongodb-org-shell mongodb-org-mongos mongodb-org-tools)

install_package.each do |pkg|
  package pkg do
    version node['mongodb3']['package']['version']
    action :install
    options '--force-yes'
  end
end

# Mongos configuration
# Create the mongodb user if not exist
user node['mongodb3']['user'] do
  action :create
end

# Create mongodb configsvr configuration 
config_nodes = search(:node, "role:configsvr")
config_rs_delim = ""
conf_repl_set_name = config_nodes.first['mongodb3']['mongod']['replication']['replSetName']
if conf_repl_set_name = 'none' or  config_nodes.first['mongodb3']['package']['version'] <= "3.2.0" 
	delim = ""
else
	delim = "#{config_nodes.first['mongodb3']['mongod']['replication']['replSetName']}/"	
	config_rs_init_clause = ""
	config_nodes.each do |cnode|
		config_rs_init_clause =  config_rs_init_clause + config_rs_delim + "{ _id: 0, host: \"<host1>:<port1>\" }"
	end 
end

execute "intiate replset configsvr #{config_nodes.first['ipaddress']}" do
command "mongo --host #{config_nodes.first["ipaddress"]}:#{config_nodes.first['mongodb3']['config']['mongod']['net']['port']} <<EOF
rs.initiate({_id: \"#{}\", configsvr: true, members: []} )
EOF>>"
user node['mongodb3']['user']
not_if "echo 'rs.status()' | mongo --host #{config_nodes.first["ipaddress"]}:#{config_nodes.first['mongodb3']['config']['mongod']['net']['port']} | grep #{config_nodes.first["ipaddress"]}" 
end

config_servers = ""

config_nodes.each do |cnode|
	
	config_servers = config_servers + "#{delim}" + cnode['ipaddress'] + ":" + cnode['mongodb3']['config']['mongod']['net']['port']
	delim = ","

end

# Create the Mongos config file
node.override['mongodb3']['config']['mongos']['sharding']['configDB'] = config_servers 
template node['mongodb3']['mongos']['config_file'] do
  source 'mongodb.conf.erb'
  owner node['mongodb3']['user']
  mode 0644
  variables(
      :config => node['mongodb3']['config']['mongos']
  )
  helpers Mongodb3Helper
end

# Create the log directory
directory File.dirname(node['mongodb3']['config']['mongos']['systemLog']['path']).to_s do
  owner node['mongodb3']['user']
  action :create
  recursive true
end

# Install runit service package
# packagecloud cookbook is not working for oracle linux.

# Adding `mongos` service with runit
#service 'mongos' do
#  supports :status => true, :start => true, :stop => true, :restart => true
#  action [:enable,:start]
#  subscribes :restart, node['mongodb3']['mongos']['config_file'] , :delayed
#end

execute 'mongos start' do
	command "mongos --config /etc/mongos.conf --fork"
	user node['mongodb3']['user']
	not_if 'ps -ef | grep mongos | grep -v "grep"'
end

shard_nodes =  search(:node, "role:shard")

shard_nodes.each do |cnode|

   execute "add shard #{cnode['ipaddress']}" do
		command "mongo --host localhost:#{node['mongodb3']['config']['mongod']['net']['port']} <<EOF
		sh.addShard(\"#{cnode["ipaddress"]}:#{cnode['mongodb3']['config']['mongod']['net']['port']\")
		EOF>>"
        user node['mongodb3']['user']
        not_if "echo 'sh.status()' | mongo --host localhost:#{node['mongodb3']['config']['mongod']['net']['port']} | grep #{cnode["ipaddress"]}" 
   end


end

