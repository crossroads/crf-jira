#
# Cookbook Name:: crf-jira
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

include_recipe 'java'
include_recipe 'java::purge_packages'
include_recipe 'postgresql'
include_recipe 'postgresql::yum_pgdg_postgresql'
include_recipe 'postgresql::server'
include_recipe 'apache2'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_proxy'
include_recipe 'apache2::mod_proxy_http'
include_recipe 'apache2::mod_proxy_ajp'
include_recipe 'apache2::mod_ssl'
include_recipe 'database::postgresql'

user node['jira']['run_user'] do
  comment "User that JIRA runs under"
end

directory node['jira']['install_path'] do
  recursive true
  owner node['jira']['run_user']
end

directory node['jira']['shared_path'] do
  recursive true
  owner node['jira']['run_user']
end

# Create the JIRA database user.
postgresql_database_user node['jira']['database_user'] do
  connection(
    :host      => node['jira']['database_host'],
    :port      => node['jira']['database_port'], 
    :username  => node['jira']['database_superuser'],
    :password  => node['jira']['database_superuser_password']
  )
  password node['jira']['database_password']
  action   :create
  only_if { node['jira']['create_database'] == true }
end

# Create the JIRA database.
postgresql_database node['jira']['database_name'] do
  connection(
    :host      => node['jira']['database_host'],
    :port      => node['jira']['database_port'],
    :username  => node['jira']['database_superuser'],
    :password  => node['jira']['database_superuser_password']
  )
  owner  node['jira']['database_user']
  action :create
  only_if { node['jira']['create_database'] == true }
end

unless FileTest.exists?("#{node['jira']['install_path']}/#{node['jira']['version']}")

  remote_file 'jira' do
    path "#{Chef::Config['file_cache_path']}/jira.tar.gz"
    source "https://downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-#{node['jira']['version']}-jira-#{node['jira']['version']}.tar.gz"
  end

  bash 'untar-jira' do
    code "(cd #{Chef::Config['file_cache_path']}; tar zxvf #{Chef::Config['file_cache_path']}/jira.tar.gz)"
  end

  bash 'install-jira' do
    code "mv #{Chef::Config['file_cache_path']}/atlassian-jira-software-#{node['jira']['version']}-standalone #{node['jira']['install_path']}/#{node['jira']['version']}"
  end

  bash 'set-jira-permissions' do
    code "chown -R #{node['jira']['run_user']} #{node['jira']['install_path']}/#{node['jira']['version']} #{node['jira']['shared_path']}"
  end

  bash 'cleanup-jira' do
    code "rm -rf #{Chef::Config['file_cache_path']}/jira.tar.gz"
  end

end

link "#{node['jira']['install_path']}/current" do
  to        "#{node['jira']['install_path']}/#{node['jira']['version']}"
  link_type :symbolic
end

directory "#{node['jira']['install_path']}/#{node['jira']['version']}" do
  recursive true
  owner node['jira']['run_user']
end

directory node['jira']['log_dir'] do
  recursive true
  owner node['jira']['run_user']
  action :create
end

directory node['jira']['pid_dir'] do
  recursive true
  owner node['jira']['run_user']
  action :create
end

directory "#{node['jira']['install_path']}/current/logs" do
  action :delete
  not_if do File.symlink?("#{node['jira']['install_path']}/current/logs") end
end

link "#{node['jira']['install_path']}/current/logs" do
  to        node['jira']['log_dir']
  link_type :symbolic
end

link "#{node['jira']['install_path']}/current/lib/postgresql-jdbc.jar" do
  to "/usr/share/java/postgresql#{node['postgresql']['version'].split('.').join}-jdbc.jar"
  link_type :symbolic
end

firewall_rule 'jira-ports' do
  protocol  :tcp
  port      [80, 443]
end

template '/usr/lib/systemd/system/jira.service' do
  source   'jira.service.erb'
end

service 'jira' do
  supports :start => true, :stop => true, :restart => true
  action [ :enable, :start ]
end

template "#{node['jira']['install_path']}/current/atlassian-jira/WEB-INF/classes/jira-application.properties" do
  source   'jira-application.properties.erb'
  owner    node['jira']['run_user']
  mode     '0640'
  notifies :reload, 'service[jira]'
end

# Create the certificates.
certificate_manage 'jira' do
  data_bag      node['jira']['certificate']['data_bag']
  data_bag_type node['jira']['certificate']['data_bag_type']
  search_id     node['jira']['certificate']['search_id']
  cert_file     node['jira']['certificate']['cert_file']
  key_file      node['jira']['certificate']['key_file']
  chain_file    node['jira']['certificate']['chain_file']
end

template "#{node['apache']['dir']}/sites-available/jira.conf" do
  source 'apache2.conf.erb'
  owner  node['apache']['user']
  group  node['apache']['user']
  mode   '0640'
  backup false
  notifies :restart, 'service[jira]'
end

template "#{node['jira']['install_path']}/current/conf/server.xml" do
  source 'server.xml.erb'
  owner node['jira']['run_user']
  mode   '0640'
  backup false
  notifies :restart, 'service[jira]'
end

apache_site 'jira' do
  enable true
end

cron 'remove-jira-backups' do
  command "/usr/bin/find #{node['jira']['shared_path']}/export -mtime +30 -type f -name \\*.zip -exec rm -rf \\{} \\;"
  minute 0
  hour   0
end
