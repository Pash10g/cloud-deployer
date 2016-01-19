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

# Install MongoDB package
install_package = %w(mongodb-org-server mongodb-org-shell mongodb-org-tools)

install_package.each do |pkg|
  package pkg do
    version node['mongodb3']['package']['version']
    action :install
    options '--force-yes'
  end
end

# Create the db path if not exist.
directory node['mongodb3']['config']['mongod']['storage']['dbPath'] do
  owner node['mongodb3']['user']
  group node['mongodb3']['group']
  mode '0755'
  action :create
  recursive true
end

unless node['mongodb3']['config']['key_file_content'].to_s.empty?
  # Create the key file if it is not exist
  key_file = node['mongodb3']['config']['mongod']['security']['keyFile']
  file key_file do
    content node['mongodb3']['config']['key_file_content']
    mode '0600'
    owner node['mongodb3']['user']
    group node['mongodb3']['group']
  end
end

# Update the mongodb config file
template node['mongodb3']['mongod']['config_file'] do
  source 'mongodb.conf.erb'
  mode 0644
  variables(
      :config => node['mongodb3']['config']['mongod']
  )
  helpers Mongodb3Helper
end



# Start the mongod service
service 'mongod' do
  supports :start => true, :stop => true, :restart => true, :status => true
  action [:enable,:start]
  subscribes :restart, "template[#{node['mongodb3']['mongod']['config_file']}]", :delayed
  subscribes :restart, "template[#{node['mongodb3']['config']['mongod']['security']['keyFile']}", :delayed
end

sleep(60)

# Setup replica initiation
repl_set_name = node['mongodb3']['config']['mongod']['replication']['replSetName']
if not (repl_set_name == 'none' or repl_set_name.nil?) and node.role?('shard')
    id_no = 0
    config_rs_init_clause = "{ _id: #{id_no}, host: \"#{node["ipaddress"]}:#{node['mongodb3']['config']['mongod']['net']['port']}\" 
    execute "add initial replicaset for shard #{node['ipaddress']}" do
  		command "mongo --host localhost:#{node['mongodb3']['config']['mongod']['net']['port']} <<EOF
  		rs.initiate({_id: \"#{repl_set_name}\", members: [#{config_rs_init_clause}]} )
  		EOF>>"
      user node['mongodb3']['user']
      not_if "echo 'rs.status()' | mongo --host localhost:#{node['mongodb3']['config']['mongod']['net']['port']} --quiet | grep #{node["ipaddress"]}" 
      retries 3
    end
end

# Setup Replica nodes
if not (repl_set_name == 'none' or repl_set_name.nil? ) and node.role?('shard')
  replica_nodes =  search(:node, %Q{role:replicaset AND replSetName:"#{repl_set_name}"})
  replica_nodes.each do |cnode|
      execute "add replicaset #{cnode['ipaddress']}" do
    		command "mongo --host localhost:#{node['mongodb3']['config']['mongod']['net']['port']} <<EOF
    		rs.add(\"#{cnode["ipaddress"]}:#{cnode['mongodb3']['config']['mongod']['net']['port']}\")
    		EOF>>"
        user node['mongodb3']['user']
        not_if "echo 'rs.status()' | mongo --host localhost:#{node['mongodb3']['config']['mongod']['net']['port']} --quiet | grep #{cnode["ipaddress"]}" 
        retries 3
      end
  end
end
