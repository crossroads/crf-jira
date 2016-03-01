name             'crf-jira'
maintainer       'Crossroads Foundation'
maintainer_email 'itdept@crossroads.org.hk'
license          'Apache 2.0'
description      'Installs and configures Atlassian JIRA'
long_description 'Installs and configures Atlassian JIRA'
version          '0.1.0'

depends 'apache2',            '>= 3.1.0'
depends 'java',               '>= 1.31.0'
depends 'postgresql',         '>= 3.4.18'
depends 'openssl',            '>= 4.0.0'
depends 'database',           '>= 4.0.6'
depends 'certificate',        '>= 1.0.0'
depends 'firewall',           '>= 1.4.0'

supports 'centos'
supports 'rhel'

