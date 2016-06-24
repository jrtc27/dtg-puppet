node 'cccc-scanner.dtg.cl.cam.ac.uk' {
  include 'dtg::minimal'

  # port configuration
  $apache_http_port = '8080'
  $apache_ssl_port = '8443'

  $varnish_http_port = '9080'
  $varnish_ssl_port = '9443'
  
  # pound deals with the SSL encryption and decryption.
  $pound_http_port = '80'
  $pound_ssl_port = '443'

  # Nasty hack to stop apache listening on port 80.
  $apache_port = $apache_http_port

  class {'apache::ubuntu': } ->
  apache::module {'cgi':} ->
  apache::module {'headers':} ->
  apache::module {'rewrite':} ->
  apache::module {'expires':} ->
  apache::site {'cccc-scanner':
    source => 'puppet:///modules/dtg/apache/cccc-scanner.conf',
  }

  # Configure apache so that it works with pound and varnish
  file_line{'apache-port-configure-http':
    line  => "Listen ${apache_http_port}",
    path  => '/etc/apache2/ports.conf',
    match => '^Listen 80.*$'
  }
  ->
  file_line{'apache-port-configure-ssl':
    line  => "Listen ${apache_ssl_port}",
    path  => '/etc/apache2/ports.conf',
    match => '^Listen .*443.*$'
  }
  ->
  file { '/etc/apache2/conf-available/cachingserver-rules.conf':
      mode   => 'u+rw,go+r',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/dtg/apache/cachingserver-rules.conf',
      notify => Service['apache2']
  }

  # stop apache so that we can use its old ports for pound
  exec { 'stop-apache':
    command => 'systemctl stop apache2',
    onlyif  => 'lsof -i TCP | grep apache | grep \'*:http\'',
    require => Package['lsof'],
  }
  ->
  package{ 'varnish':
    ensure => installed
  }
  ->
  package{ 'pound':
    ensure => installed
  }
  ->
  file_line{'pound-startup':
    line   => 'startup=1',
    path   => '/etc/default/pound',
    match  => '^startup.*$',
    notify => Service['pound']
  }

  service { 'varnish':
      ensure  => 'running',
      enable  => true,
      require => Package['varnish'],
  }

  service { 'pound':
      ensure  => 'running',
      enable  => true,
      require => Package['pound'],
  }

  file { '/etc/pound/pound.cfg':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/dtg/cccc/pound.cfg',
      notify => Service['pound']
  }
  ->
  file { '/etc/varnish/cdn.vcl':
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/dtg/cdn/varnish/cdn.vcl'
  }
  ->
  file_line{'configure-varnish-vcl':
    notify => Service['varnish'],
    line   => '-f /etc/varnish/cdn.vcl \\',
    path   => '/etc/default/varnish',
    match  => '.*-f /etc/varnish/.*vcl \\.*'
  }
  ->
  file_line{'configure-varnish-memory':
    notify => Service['varnish'],
    line   => "-s malloc,512m\"",
    path   => '/etc/default/varnish',
    match  => '.*-s malloc,.*"'
  }
  ->
  file_line{'varnish-setup-http-listening-ports':
    notify => Service['varnish'],
    line   => "DAEMON_OPTS=\"-a :${varnish_http_port} -a :${varnish_ssl_port} \\",
    path   => '/etc/default/varnish',
    match  => '^DAEMON_OPTS=.*'
  }
  ->
  exec { 'start-apache':
    command => 'systemctl start apache2',
    unless  => 'systemctl is-active apache2.service',
  }

  vcsrepo { '/etc/www-bare':
    ensure   => bare,
    provider => git,
    source   => 'git://github.com/ucam-cl-dtg/cccc-scanner-www',
    owner    => 'root',
    group    => 'root'
  }
  ->
  file { '/etc/www-bare/hooks/post-update':
    ensure => 'file',
    owner  => 'root',
    group  => 'root',
    mode   => '0775',
    source => 'puppet:///modules/dtg/cccc/post-update-www.hook',
  }
  ->
  exec { 'run-www-hook':
    command => '/etc/www-bare/hooks/post-update',
    creates => '/var/www/.git',
  }
  # Use letsencrypt to get a certificate
  class {'letsencrypt':
    email          => $::from_address,
    configure_epel => false,
    require        => [Service['apache2'], Service['pound']],
  } ->
  letsencrypt::certonly { $::fqdn:
    plugin          => 'webroot',
    webroot_paths   => ['/var/www/'],
    manage_cron     => true,
    # Evil hack because pound requires everything in the same file
    additional_args => [" && cat /etc/letsencrypt/live/${::fqdn}/privkey.pem /etc/letsencrypt/live/${::fqdn}/fullchain.pem > /etc/letsencrypt/live/${::fqdn}/privkey_fullchain.pem"],
  } ->
  exec {'restart pound':
    command     => 'service pound restart',
    refreshonly => true,
  }

  class {'dtg::firewall::publichttp':}

  class {'dtg::firewall::publichttps':}
}

if ( $::monitor ) {
  nagios::monitor { 'cccc-scanner':
    parents    => 'nas04',
    address    => 'cccc-scanner.dtg.cl.cam.ac.uk',
    hostgroups => ['ssh-servers', 'http-servers', 'https-servers'],
  }
  
  munin::gatherer::async_node { 'cccc-scanner': }
}
