class munin::gatherer(
  $listen_ip = "*",
  $server_name = "munin",
  $tls_cert_file = undef,
  $tls_cert_chain_file = undef,
  $tls_key_file = undef,
  $graph_strategy = "cgi",
  $html_strategy = "cgi",
  $alerts_email = $from_address,
  $contact = "dtg",
  $graph_data_size = "huge",
  $extra_apache_config = '',
  $lets_encrypt = true,
) {
  package { [ "munin", "libcgi-fast-perl", "libapache2-mod-fcgid" ]:
    ensure => installed
  }
  exec {'Enable mod rewrite':
    command   => "a2enmod rewrite"
  }
  file { '/etc/munin/munin-conf.d/':
    ensure => directory,
    require => Package['munin'],
  }

  apache::site { "munin":
    content => template("munin/munin.erb")
  }
  file { "/etc/apache2/conf.d/munin":
    ensure => absent,
  }
  file { "/etc/munin/munin.conf":
    content => template("munin/munin-conf.erb"),
  }
  if $lets_encrypt {
    letsencrypt::certonly { $server_name:
      plugin        => 'webroot',
      webroot_paths => ['/var/cache/munin/www/'],
      manage_cron   => true,
      require       => Class['letsencrypt'],
    }
  }
}

class munin::gatherer::async(
) {
  require 'munin::gatherer'
  dtg::sshkeygen{'munin':
    homedir => '/var/lib/munin',
    # This require is actually meant for the whole class but I don't know how to do that (drt24).
    require => Package['munin-async'],
  }
}

define munin::gatherer::configure_node ( $override_lines = '') {
  $munin_node_host = $title
  file { "/etc/munin/munin-conf.d/$munin_node_host":
    ensure  => present,
    content => template("munin/node.erb"),
    require => File["/etc/munin/munin-conf.d/"],
  }
}
define munin::gatherer::async_node ( $override_lines = '') {
  $munin_node_host = $title
  file { "/etc/munin/munin-conf.d/$munin_node_host":
    ensure  => present,
    content => template("munin/node-async.erb"),
    require => File["/etc/munin/munin-conf.d/"],
  }
}

define munin::node::plugin( $ensure = "symlink", $target = "") {
  $base = "/usr/share/munin/plugins"
  if ( $target ) {
    if ( $target =~ /\/.*/ ) {
      $target_path = $target
    } else {
      $target_path = "$base/${target}"
    }
  } else {
    $target_path = "$base/${title}"
  }
  $link = "/etc/munin/plugins/${title}"

  file { "$link":
    ensure => $ensure,
    target => $target_path,
    require => Package["munin-node"],
    notify => Service["munin-node"],

  }
}

class munin::node (
  $node_allow_ips = ['^127\.0\.0\.1$'],
  $node_timeout = "15",
  $async = true,
  $async_key = '',
) {
  package { [ "munin-node", "munin-plugins-extra", "libcache-cache-perl" ]:
    ensure => installed
  } ->
  exec { "munin-node-configure":
    command  => 'munin-node-configure --shell | sh',
    provider => shell,
  } ->
  service { "munin-node":
    ensure => running
  }

  if $async {
    package { 'munin-async':
      ensure => installed,
    } ->
    service { 'munin-async':
      ensure  => running,
      require => Service['munin-node'],
    } ->
    ssh_authorized_key { 'munin-async':
      user    => 'munin-async',
      type    => 'ssh-rsa',
      key     => $async_key,
      ensure  => 'present',
      options => ['no-port-forwarding', 'no-agent-forwarding', 'no-X11-forwarding', 'no-pty', 'no-user-rc', 'command="/usr/sbin/munin-async  --spooldir /var/lib/munin-async --spoolfetch"']
    }
  }

  file { "/etc/munin/munin-node.conf":
    ensure => present,
    content => template("munin/munin-node.conf.erb"),
    require => Package["munin-node"],
    notify => Service[ "munin-node"]
  }
  # Overrides for default content of munin-node so that we don't get noise from filesystems coming and going
  # Also specify the user required for the unbound plugins
  file { '/etc/munin/plugin-conf.d/z-overrides':
    ensure => file,
    content => '[df*]
    env.warning 92
    env.critical 98
    env.exclude none unknown binfmt_misc debugfs devtmpfs fuse.gvfs-fuse-daemon iso9660 ramfs romfs rpc_pipefs squashfs tmpfs udf
[diskstats]
    env.exclude none unknown ok
[unbound*]
    user root
    env.statefile /var/lib/munin-node/plugin-state/unbound-state
    env.unbound_conf /etc/unbound/unbound.conf
    env.unbound_control /usr/sbin/unbound-control
',
    require => Package["munin-node"],
    notify => Service[ "munin-node"],
  }
}
