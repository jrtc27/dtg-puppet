node /^otter(-\d+)?/ {

  $dashboard_version = '1.0.10-SNAPSHOT'
  $handins_version   = '1.0.6-SNAPSHOT'
  $questions_version = '1.0.8-SNAPSHOT'
  $signups_version   = '1.0.8-SNAPSHOT'

  $install_directory = '/local/data/webapps'
  
  include 'dtg::minimal'

  $tomcat_version = '8'
  class {'dtg::tomcat': version => $tomcat_version}
  ->
  file {"/var/lib/tomcat${tomcat_version}/webapps/ROOT/index.html":
    ensure => absent
  }
  ->
  file {"/var/lib/tomcat${tomcat_version}/webapps/ROOT/index.jsp":
    source => 'puppet:///modules/dtg/tomcat/berrycider-redirect.jsp'
  }
  ->
  class {'dtg::firewall::publichttp':}
  ->
  class {'dtg::firewall::80to8080':
    private => false,
  }
  ->
  file {[$install_directory,'/local/data/handins','/local/data/questions']:
    ensure => directory,
    group  => "tomcat${tomcat_version}",
    mode   => 'a=xr,ug+wrx,g+s'
  }
  ->
  dtg::nexus::fetch{'download-dashboard':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'dashboard',
    artifact_version      => $dashboard_version,
    artifact_type         => 'war',
    destination_directory => "${install_directory}/ott-dashboard",
    symlink               => "/var/lib/tomcat${tomcat_version}/webapps/dashboard.war",
  }
  ->
  file {"/var/lib/tomcat${tomcat_version}/conf/Catalina/localhost/dashboard.xml":
    source => 'puppet:///modules/dtg/tomcat/berrycider-context.xml'
  }
  ->
  dtg::nexus::fetch{'download-handins':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'handins',
    artifact_version      => $handins_version,
    artifact_type         => 'war',
    destination_directory => "${install_directory}/ott-handins",
    symlink               => "/var/lib/tomcat${tomcat_version}/webapps/handins.war",
  }
  ->
  file {"/var/lib/tomcat${tomcat_version}/conf/Catalina/localhost/handins.xml":
    source => 'puppet:///modules/dtg/tomcat/berrycider-context.xml'
  }
  ->
  dtg::nexus::fetch{'download-questions':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'questions',
    artifact_version      => $questions_version,
    artifact_type         => 'war',
    destination_directory => "${install_directory}/ott-questions",
    symlink               => "/var/lib/tomcat${tomcat_version}/webapps/questions.war",
  }
  ->
  file {"/var/lib/tomcat${tomcat_version}/conf/Catalina/localhost/questions.xml":
    source => 'puppet:///modules/dtg/tomcat/berrycider-context.xml'
  }
  ->
  dtg::nexus::fetch{'download-signups':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'signups',
    artifact_version      => $signups_version,
    artifact_type         => 'war',
    destination_directory => "${install_directory}/ott-signups",
    symlink               => "/var/lib/tomcat${tomcat_version}/webapps/signups.war",
  }
  ->
  file {"/var/lib/tomcat${tomcat_version}/conf/Catalina/localhost/signups.xml":
    source => 'puppet:///modules/dtg/tomcat/berrycider-context.xml'
  }

  class { 'postgresql::globals':
    version => '9.4',
  }
  ->
  class { 'postgresql::server':
    ip_mask_deny_postgres_user => '0.0.0.0/0',
    ip_mask_allow_all_users    => '127.0.0.1/32',
    listen_addresses           => '*',
    ipv4acls                   => ['hostssl all all 127.0.0.1/32 md5'],
  }
  ->
  postgresql::server::db{'handins':
    user     => 'handins',
    password => 'handins',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  ->
  dtg::nexus::fetch{'download-handins-backup':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'handins-backup',
    artifact_version      => '1.0.0-SNAPSHOT',
    artifact_type         => 'zip',
    artifact_classifier   => 'live',
    destination_directory => "${install_directory}/ott-handins-backup",
    action                => 'unzip'
  }
  ->
  exec{'restore-handins-backup':
    command     => "psql -U handins -d handins -h localhost -f ${install_directory}/ott-handins-backup/handins-backup-1.0.0-SNAPSHOT/target/backup.sql",
    environment => 'PGPASSWORD=handins',
    path        => '/usr/bin:/bin',
    unless      => 'psql -U handins -h localhost -d handins -t -c "select * from Bin limit 1"'
  }
  ->
  postgresql::server::db{'notifications':
    user     => 'notifications',
    password => 'notifications',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  ->
  dtg::nexus::fetch{'download-dashboard-backup':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'dashboard-backup',
    artifact_version      => '1.0.0-SNAPSHOT',
    artifact_type         => 'zip',
    artifact_classifier   => 'live',
    destination_directory => "${install_directory}/ott-dashboard-backup",
    action                => 'unzip'
  }
  ->
  exec{'restore-dashboard-backup':
    command     => "psql -U notifications -d notifications -h localhost -f ${install_directory}/ott-dashboard-backup/dashboard-backup-1.0.0-SNAPSHOT/target/backup.sql",
    environment => 'PGPASSWORD=notifications',
    path        => '/usr/bin:/bin',
    unless      => 'psql -U notifications -h localhost -d notifications -t -c "select * from Users limit 1"'
  }
  ->
  postgresql::server::db{'questions':
    user     => 'questions',
    password => 'questions',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  ->
  dtg::nexus::fetch{'download-questions-backup':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'questions-backup',
    artifact_version      => '1.0.0-SNAPSHOT',
    artifact_type         => 'zip',
    artifact_classifier   => 'live',
    destination_directory => "${install_directory}/ott-questions-backup",
    action                => 'unzip'
  }
  ->
  exec{'restore-questions-backup':
    command     => "psql -U questions -d questions -h localhost -f ${install_directory}/ott-questions-backup/questions-backup-1.0.0-SNAPSHOT/target/backup.sql",
    environment => 'PGPASSWORD=questions',
    path        => '/usr/bin:/bin',
    unless      => 'psql -U questions -h localhost -d questions -t -c "select * from Users limit 1"'
  }
  ->
  postgresql::server::db{'signups':
    user     => 'signups',
    password => 'signups',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  ->
    dtg::nexus::fetch{'download-signups-backup':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'signups-backup',
    artifact_version      => '1.0.0-SNAPSHOT',
    artifact_type         => 'zip',
    artifact_classifier   => 'live',
    destination_directory => "${install_directory}/ott-signups-backup",
    action                => 'unzip'
  }
  ->
  exec{'restore-signups-backup':
    command     => "psql -U signups -d signups -h localhost -f ${install_directory}/ott-signups-backup/signups-backup-1.0.0-SNAPSHOT/target/backup.sql",
    environment => 'PGPASSWORD=signups',
    path        => '/usr/bin:/bin',
    unless      => 'psql -U signups -h localhost -d signups -t -c "select * from Users limit 1"'
  }
  ->
  postgresql::server::db{'log':
    user     => 'log',
    password => 'log',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  ->
    dtg::nexus::fetch{'download-frontend-backup':
    groupID               => 'uk.ac.cam.cl.dtg.teaching',
    artifact_name         => 'frontend-backup',
    artifact_version      => '1.0.0-SNAPSHOT',
    artifact_type         => 'zip',
    artifact_classifier   => 'live',
    destination_directory => "${install_directory}/ott-frontend-backup",
    action                => 'unzip'
  }
  ->
  exec{'restore-frontend-backup':
    command     => "psql -U log -d log -h localhost -f ${install_directory}/ott-frontend-backup/frontend-backup-1.0.0-SNAPSHOT/target/backup.sql",
    environment => 'PGPASSWORD=log',
    path        => '/usr/bin:/bin',
    unless      => 'psql -U log -h localhost -d log -t -c "select * from Log limit 1"'
  }

  $packages = ['maven','openjdk-8-jdk','puppet-el']
  package{$packages:
    ensure => installed,
  }

  group {'jenkins':
    ensure => present,
  }
  ->
  user {'jenkins':
    ensure   => present,
    gid      => 'jenkins',
    password => '*',
  }
  ->
  file {'/home/jenkins':
    ensure => directory,
    owner  => 'jenkins',
    group  => 'jenkins',
    mode   => '0755',
  }
  ->
  file {'/home/jenkins/.ssh/':
    ensure => directory,
    owner  => 'jenkins',
    group  => 'jenkins',
    mode   => '0755',
  }
  ->
  file {'/home/jenkins/.ssh/authorized_keys':
    ensure  => file,
    mode    => '0644',
    content => 'from="128.232.21.0" ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAlQzIFjqes3XB09BAS9+lhZ9QuLRsFzLb3TwQJET/Q6tqotY41FgcquONrrEynTsJR8Rqko47OUH/49vzCuLMvOHBg336UQD954oIUBmyuPBlIaDH3QAGky8dVYnjf+qK6lOedvaUAmeTVgfBbPvHfSRYwlh1yYe+9DckJHsfky2OiDkych9E+XgQ4GipLf8Cw6127eiC3bQOXPYdZh7uKnW6vpnVPFPF5K1dSaUo3GxcpYt3OsT3IqB640m8mgekWtOmCuAP+9IEBFmCozwpqLz+EWv6wtova7tbVCkrU2iJwTbJzOUCvWv5JHYjAi/pWNIsKnWpFF9+m4th26GY4Q== jenkins@dtg-ci.cl.cam.ac.uk',
  }

  
}

if ( $::monitor ) {
  nagios::monitor { 'otter':
    parents    => 'nas04',
    address    => 'otter.cl.cam.ac.uk',
    hostgroups => [ 'ssh-servers', 'http-servers'],
  }
  munin::gatherer::async_node { 'otter': }
}
