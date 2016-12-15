# Exim configuration for client servers telling them which smtp server to use
# $smarthost will be used as the dc_smarthost
# $mail_domain will be used for dc_readhost
class exim::satellite ($smarthost, $mail_domain) {
  package {'exim':
    ensure => present,
    name   => 'exim4-daemon-light',
  }
  file {'/etc/exim4/update-exim4.conf.conf':
    ensure  => file,
    content => template('exim/update-exim4.conf.conf.erb'),
    require => Package['exim'],
    notify  => Exec['update-exim4.conf'],
  }
  file {'/etc/mailname':
    ensure  => file,
    content => $mail_domain,
    notify  => Exec['update-exim4.conf'],
  }

  exec {'update-exim4.conf':
    refreshonly => true,
  }

  package {'mailx':
    ensure => present,
    name   => 'bsd-mailx',
  }
  package {'heirloom-mailx':
    ensure  => absent,
    require => Package['mailx'],
  }
}