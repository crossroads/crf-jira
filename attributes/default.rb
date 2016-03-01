#
## Cookbook Name:: crf-jira
## Recipe:: default
##
## Copyright 2015 Crossroads Foundation
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

::Chef::Node.send(:include, Opscode::OpenSSL::Password)

override['apache']['default_site_enabled'] = false

default['jira']['version']                      = '5.9.5'
default['jira']['install_path']                 = '/opt/jira'
default['jira']['shared_path']                  = '/var/jira'
default['jira']['run_user']                     = 'jira'
default['jira']['log_dir']                      = '/var/log/jira'
default['jira']['pid_dir']                      = "#{node['jira']['install_path']}/current/work"
default['jira']['create_database']              = false
default['jira']['database_name']                = 'jira'
default['jira']['database_user']                = 'jira'
default['jira']['database_password']            = secure_password
default['jira']['database_host']                = '127.0.0.1'
default['jira']['database_port']                = node['postgresql']['config']['port']
default['jira']['database_superuser']           = 'postgres'
default['jira']['database_superuser_password']  = node['postgresql']['password']['postgres']
default['jira']['bind_tomcat_port']             = '8000'
default['jira']['bind_http_port']               = '8080'
default['jira']['bind_ajp_port']                = '8009'
default['jira']['context_path']                 = '/'
default['jira']['hostname']                     = 'jira'
default['jira']['domainname']                   = "#{node['jira']['hostname']}.#{node['domain']}"
default['jira']['bind_address']                 = '_default_'
default['jira']['certificate']['data_bag']      = nil
default['jira']['certificate']['data_bag_type'] = 'unencrypted'
default['jira']['certificate']['search_id']     = 'cups'
default['jira']['certificate']['cert_file']     = "#{node['fqdn']}.pem"
default['jira']['certificate']['key_file']      = "#{node['fqdn']}.key"
default['jira']['certificate']['chain_file']    = "#{node['hostname']}-bundle.crt"

