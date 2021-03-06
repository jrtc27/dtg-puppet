#Configuration for deviceanalyzer related stuff

# WARNING. Deviceanalyzer needs an SSL certificate and htpasswd configuration in /etc/nginx/sec. This is not stored in puppet. 

$deviceanalyzer_ips = dnsLookup('deviceanalyzer.dtg.cl.cam.ac.uk')
$deviceanalyzer_ip = $deviceanalyzer_ips[0]
$deviceanalyzer_upload_ips = dnsLookup('upload.deviceanalyzer.dtg.cl.cam.ac.uk')
$deviceanalyzer_upload_ip = $deviceanalyzer_upload_ips[0]

$deviceanalyzer_www_ip = dnsLookup('deviceanalyzer-www.dtg.cl.cam.ac.uk')

node 'deviceanalyzer.dtg.cl.cam.ac.uk' {
  include 'dtg::minimal'

  class {'dtg::deviceanalyzer':}

  # open up ports 80,443,2468
  class {'dtg::firewall::publichttp':}
  class {'dtg::firewall::publichttps':}
  firewall { '030-xmlsocketserver accept tcp 2468 (xmlsocketserver) from anywhere':
    proto  => 'tcp',
    dport  => 2468,
    action => 'accept',
  }

  # Packages which should be installed
  $packagelist = ['openjdk-8-jdk', 'jetty8', 'nginx', 'autofs']
  package {
    $packagelist:
      ensure => installed
  }

  file {'/etc/auto.mnt':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => 'a=r',
    content => 'nas04   nas04.dtg.cl.cam.ac.uk:/dtg-pool0/deviceanalyzer
nas04-index   nas04.dtg.cl.cam.ac.uk:/dtg-pool0/deviceanalyzer-datadivider
nas04-snapshot   nas04.dtg.cl.cam.ac.uk:/dtg-pool0/deviceanalyzer-2016-03-14 ',
  } ->
  file_line {'mount nas':
    line => '/mnt   /etc/auto.mnt',
    path => '/etc/auto.master',
  }

  file {'/nas4':
    ensure => link,
    target => '/mnt/nas04',
  }
  file {'/nas4-index':
    ensure => link,
    target => '/mnt/nas04-index',
  }
  file {'/nas4-snapshot':
    ensure => link,
    target => '/mnt/nas04-snapshot',
  }

  # set up nginx and jetty config
  file {'/etc/nginx/sites-enabled/default':
    ensure => absent,
  }
  file {'/etc/nginx/sites-enabled/deviceanalyzer.nginx.conf':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/dtg/deviceanalyzer/deviceanalyzer.nginx.conf',
  }
  file {'/etc/default/jetty8':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/dtg/deviceanalyzer/jetty8',
  }
  file {'/etc/init.d/xmlsocketserver':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/dtg/deviceanalyzer/xmlsocketserver.initd',
  }
  file {'/etc/network/interfaces':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/dtg/deviceanalyzer/interfaces',
  }

  # ensure webapps directory is writeable by the non-standard 'www-deviceanalyzer' user
  file { '/var/lib/jetty8/webapps':
    ensure => directory,
    owner  => 'www-deviceanalyzer',
    group  => 'adm',
    mode   => '0755',
  }
  file { '/var/lib/jetty8':
    ensure => directory,
    owner  => 'www-deviceanalyzer',
    group  => 'adm',
    mode   => '0755',
  }
  file { '/var/log/jetty8':
    ensure => directory,
    owner  => 'www-deviceanalyzer',
    group  => 'adm',
    mode   => '0755',
  }

}

node 'deviceanalyzer-database.dtg.cl.cam.ac.uk' {

  include 'dtg::minimal'
  class { 'postgresql::globals':
    version => '9.4',
  }
  ->
  class { 'postgresql::server':
    ip_mask_deny_postgres_user => '0.0.0.0/0',
    ip_mask_allow_all_users    => '127.0.0.1/32',
    listen_addresses           => '*',
    ipv4acls                   => ['hostssl all all 127.0.0.1/32 md5',
                                  'host androidusage androidusage 128.232.98.188/32 md5',
                                  'host androidusage androidusage 128.232.21.105/32 md5',
                                  'host androidusage androidusage 128.232.21.104/32 md5',
                                  'host androidusage androidusage 128.232.21.132/32 md5']
  }
  ->
  postgresql::server::db{'androidusage':
    user     => 'androidusage',
    password => 'androidusage',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  ->
  postgresql::server::db{'androidstats':
    user     => 'androidstats',
    password => 'J4s98AK0w',
    encoding => 'UTF-8',
    grant    => 'ALL'
  }
  dtg::firewall::postgres{'deviceanalyzer':
    source      => $deviceanalyzer_ip,
    source_name => 'deviceanalyzer',
  }
  dtg::firewall::postgres{'deviceanalyzer-upload':
    source      => $deviceanalyzer_upload_ip,
    source_name => 'upload.deviceanalyzer',
  }
  dtg::firewall::postgres{'deviceanalyzer-www':
    source      => $deviceanalyzer_www_ip,
    source_name => 'deviceanalyzer-www',
  }

}

if ( $::monitor ) {
  nagios::monitor { 'deviceanalyzer-database':
    parents    => 'nas04',
    address    => 'deviceanalyzer-database.dtg.cl.cam.ac.uk',
    hostgroups => [ 'ssh-servers' ],
  }
  nagios::monitor { 'deviceanalyzer':
    parents    => '',
    address    => 'deviceanalyzer.cl.cam.ac.uk',
    hostgroups => [ 'http-servers', 'ssh-servers', 'https-servers' ],
  }
  nagios::monitor { 'secure.deviceanalyzer':
    parents    => 'deviceanalyzer',
    address    => 'secure.deviceanalyzer.cl.cam.ac.uk',
    hostgroups => [ 'http-servers', 'https-servers' ],
  }
  nagios::monitor { 'upload.deviceanalyzer':
    parents    => 'deviceanalyzer',
    address    => 'upload.deviceanalyzer.cl.cam.ac.uk',
    hostgroups => [ 'http-servers', 'https-servers', 'xml-servers'],
  }
  munin::gatherer::async_node { 'deviceanalyzer-www': }
}
