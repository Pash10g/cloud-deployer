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

#Setup mongos service
template '/etc/init/mongos-service.conf' do
	source 'mongos-service.conf.erb'
	owner 'root'
	group 'root'
	notifies :run, 'execute[initctl run]', :immediate
end

execute "initctl run" do
	command "sudo initctl list"
	action :nothing
end



# Create mongodb configsvr configuration 
config_nodes = search(:node, "role:configsvr")
config_nodes = config_nodes.sort do |f, s| f.ipaddress <=> s.ipaddress end
config_rs_delim = ""
conf_repl_set_name = config_nodes.first['mongodb3']['config']['mongod']['replication']['replSetName']
if conf_repl_set_name == 'none' or  config_nodes.first['mongodb3']['package']['version'].to_s < "3.2.0" or conf_repl_set_name.nil? 
	delim = ""
else
	delim = "#{conf_repl_set_name}/"	
	config_rs_init_clause = ""
	id_no = 0
	config_nodes.each do |cnode|
		
		config_rs_init_clause =  config_rs_init_clause + config_rs_delim + "{ _id: #{id_no}, host: \"#{cnode["ipaddress"]}:#{cnode['mongodb3']['config']['mongod']['net']['port']}\" }"
		config_rs_delim = ","
		id_no = id_no + 1
	end 
	
	execute "intiate replset configsvr " do
		command "mongo --host #{config_nodes.first["ipaddress"]}:#{config_nodes.first['mongodb3']['config']['mongod']['net']['port']} <<EOF
		rs.initiate({_id: \"#{conf_repl_set_name}\", configsvr: true, members: [#{config_rs_init_clause}]} )
		EOF>>"
		user node['mongodb3']['user']
		not_if "echo 'rs.status()' | mongo --host  #{config_nodes.first["ipaddress"]}:#{config_nodes.first['mongodb3']['config']['mongod']['net']['port']} --quiet | grep #{config_nodes.first["ipaddress"]}" 
	end

end


config_servers = ""

config_nodes.each do |cnode|
	
	config_servers = config_servers + "#{delim}" + cnode['ipaddress'] + ":" + cnode['mongodb3']['config']['mongod']['net']['port'].to_s
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


# Start the mongos service
service 'mongos-service' do
  supports :start => true, :stop => true, :restart => true, :status => true
  action [:enable,:start]
  subscribes :restart, "template[#{node['mongodb3']['mongos']['config_file']}]", :delayed
end

shard_nodes =  search(:node, "role:shard")

shard_nodes.each do |cnode|
   
   repl_set_name = cnode['mongodb3']['config']['mongod']['replication']['replSetName']
   if not (repl_set_name =~ /none/ or repl_set_name.nil?)
   	prefix = "#{repl_set_name}/"
   else
   	prefix = ""
   end
   
   
   
   execute "add shard #{cnode['ipaddress']}" do
		command "mongo --host localhost:#{node['mongodb3']['config']['mongos']['net']['port']} <<EOF
		sh.addShard(\"#{prefix}#{cnode["ipaddress"]}:#{cnode['mongodb3']['config']['mongod']['net']['port']}\")
		EOF>>"
		retries 5
		retry_delay 10
        user node['mongodb3']['user']
        not_if "echo 'sh.status()' | mongo --host localhost:#{node['mongodb3']['config']['mongos']['net']['port']} --quiet | grep #{cnode["ipaddress"]}" 
   end


end

