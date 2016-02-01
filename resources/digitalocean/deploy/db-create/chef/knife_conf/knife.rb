current_dir = File.dirname(__FILE__)
org_name    = ENV['CHEF_ORGNAME']
puts "Using organization #{org_name}"
log_level                :info
log_location             STDOUT
node_name                "admin"
client_key               "#{current_dir}/admin.pem"
validation_key           "#{current_dir}/#{org_name}-validator.pem"
chef_server_url          "https://<chef-server>/organizations/#{org_name}"
validation_client_name   "#{org_name}-validator"
cookbook_path            ["/root/.chef/cookbooks"]
trusted_certs_dir        "#{current_dir}/trusted_certs"
