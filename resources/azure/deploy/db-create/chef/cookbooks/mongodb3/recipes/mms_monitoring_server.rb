#
# Cookbook Name:: mongodb3
# Recipe:: mms_monitoring_server
#
# Copyright 2015, Pavel Duchovny
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

include_recipe "mongodb3::default"

# Install curl
package 'curl' do
  action :install
end

# Set variables by platform
case node['platform_family']
  when 'rhel', 'fedora'
    mms_server_source = 'https://downloads.mongodb.com/on-prem-mms/rpm/mongodb-mms-2.0.1.332-1.x86_64.rpm?_ga=1.13465655.1636956437.1454340685'
    mms_server_file = '/root/mongodb-mms-monitoring-agent-latest.x86_64.rpm'
  when 'debian'
    mms_server_source = 'https://downloads.mongodb.com/on-prem-mms/deb/mongodb-mms_2.0.1.332-1_x86_64.deb?_ga=1.189190187.1636956437.1454340685'
    mms_server_file = '/root/mongodb-mms_2.0.1.332-1_x86_64.deb'
end



# Download the mms automation agent manager latest
remote_file mms_server_file do
  source mms_server_source
  action :create
end

# Install package
case node['platform_family']
  when 'rhel', 'fedora'
    rpm_package 'mongodb-mms-monitoring-server' do
      source mms_server_file
      action :install
    end
  when 'debian'
    dpkg_package 'mongodb-mms-monitoring-server' do
      source mms_server_file
      action :install
    end
end

# Create or modify the mms agent config file
template '/opt/mongodb/mms/conf/conf-mms.properties' do
  source 'conf-mms.properties.erb'
  mode 0600
  owner 'mongodb-mms'
  group 'mongodb-mms'
  variables(
      :config => node['mongodb3']['config']['mms_server']
  )
end

# Start the mms automation agent
service 'mongodb-mms' do
  # The service provider of MMS Agent for Ubuntu is upstart
  supports :status => true, :restart => true, :stop => true
  action [ :enable, :start ]
end
