#
# Cookbook Name:: crf-confluence
# Recipe:: default
#
# Copyright 2015 Crossroads Foundation
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe "java"
include_recipe "java::purge_packages"
include_recipe "postgresql"
include_recipe "postgresql::yum_pgdg_postgresql"
include_recipe "postgresql::server"
include_recipe "apache2"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_proxy"
include_recipe "apache2::mod_proxy_http"
include_recipe "apache2::mod_proxy_ajp"
include_recipe "apache2::mod_ssl"
include_recipe "database::postgresql"
include_recipe "graphviz"

user node['confluence']['run_user'] do
  comment "User that Confluence runs under"
end

directory node['confluence']['install_path'] do
  recursive true
  owner node['confluence']['run_user']
end

directory node['confluence']['shared_path'] do
  recursive true
  owner node['confluence']['run_user']
end

# Create the Confluence database user.
postgresql_database_user node['confluence']['database_user'] do
  connection(
    :host      => '127.0.0.1',
    :port      => node['postgresql']['config']['port'],
    :username  => 'postgres',
    :password  => node['postgresql']['password']['postgres']
  )
  password node['confluence']['database_password']
  action   :create
end

# Create the Confluence database.
postgresql_database node['confluence']['database_name'] do
  connection(
    :host      => '127.0.0.1',
    :port      => node['postgresql']['config']['port'],
    :username  => 'postgres',
    :password  => node['postgresql']['password']['postgres']
  )
  owner  node['confluence']['database_user']
  action :create
end

unless FileTest.exists?("#{node['confluence']['install_path']}/#{node['confluence']['version']}")

  remote_file "confluence" do
    path "#{Chef::Config['file_cache_path']}/confluence.tar.gz"
    source "http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-#{node['confluence']['version']}.tar.gz"
  end

  bash "untar-confluence" do
    code "(cd #{Chef::Config['file_cache_path']}; tar zxvf #{Chef::Config['file_cache_path']}/confluence.tar.gz)"
  end

  bash "install-confluence" do
    code "mv #{Chef::Config['file_cache_path']}/atlassian-confluence-#{node['confluence']['version']} #{node['confluence']['install_path']}/#{node['confluence']['version']}"
  end

  bash "set-confluence-permissions" do
    code "chown -R #{node['confluence']['run_user']} #{node['confluence']['install_path']}/#{node['confluence']['version']} #{node['confluence']['shared_path']}"
  end

  bash "cleanup-confluence" do
    code "rm -rf #{Chef::Config['file_cache_path']}/confluence.tar.gz"
  end

end

link "#{node['confluence']['install_path']}/current" do
  to        "#{node['confluence']['install_path']}/#{node['confluence']['version']}"
  link_type :symbolic
end

directory "#{node['confluence']['install_path']}/#{node['confluence']['version']}" do
  recursive true
  owner node['confluence']['run_user']
end

directory node['confluence']['log_dir'] do
  recursive true
  owner node['confluence']['run_user']
  action :create
end

directory node['confluence']['pid_dir'] do
  recursive true
  owner node['confluence']['run_user']
  action :create
end

directory "#{node['confluence']['install_path']}/current/logs" do
  action :delete
  not_if do File.symlink?("#{node['confluence']['install_path']}/current/logs") end
end

link "#{node['confluence']['install_path']}/current/logs" do
  to        node['confluence']['log_dir']
  link_type :symbolic
end

link "#{node['confluence']['install_path']}/current/lib/postgresql-jdbc.jar" do
  to "/usr/share/java/postgresql#{node['postgresql']['version'].split('.').join}-jdbc.jar"
  link_type :symbolic
end

firewall_rule 'confluence-ports' do
  protocol  :tcp
  port      [80, 443]
end

template "/usr/lib/systemd/system/confluence.service" do
  source   'confluence.service.erb'
end

service "confluence" do
  supports :start => true, :stop => true, :restart => true
  action [ :enable, :start ]
end

template "#{node['confluence']['install_path']}/current/confluence/WEB-INF/classes/confluence-init.properties" do
  source   "confluence-init.properties.erb"
  owner    node['confluence']['run_user']
  mode     "0640"
  notifies :reload, 'service[confluence]'
end

# Create the certificates.
certificate_manage 'confluence' do
  data_bag      node['confluence']['certificate']['data_bag']
  data_bag_type node['confluence']['certificate']['data_bag_type']
  search_id     node['confluence']['certificate']['search_id']
  cert_file     node['confluence']['certificate']['cert_file']
  key_file      node['confluence']['certificate']['key_file']
  chain_file    node['confluence']['certificate']['chain_file']
end

template "#{node['apache']['dir']}/sites-available/confluence.conf" do
  source "apache2.conf.erb"
  owner  node['apache']['user']
  group  node['apache']['user']
  mode   "0640"
  backup false
end

apache_site "confluence" do
  enable true
end
