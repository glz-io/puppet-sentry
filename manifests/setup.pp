# == Class: sentry::setup
#
# Installs Sentry prerequisites
#
# === Params
#
# group: UNIX group to own Sentry files
# path: path into which to create virtualenv and install Sentry
# user: UNIX user to own Sentry files
#
# === Authors
#
# Scott Merrill <smerrill@covermymeds.com>
#
# === Copyright
#
# Copyright 2016 CoverMyMeds
#
class sentry::setup (
  $group             = $sentry::group,
  $path              = $sentry::path,
  $user              = $sentry::user,
) {
  assert_private()

  group { $group:
    ensure => present,
  }

  user { $user:
    ensure  => present,
    gid     => $group,
    home    => $path,
    shell   => '/bin/false',
    require => Group[$group],
  }

  file { '/var/log/sentry':
    ensure  => directory,
    owner   => 'sentry',
    group   => 'sentry',
    mode    => '0755',
    require => User[$user],
  }

  case $::osfamily {
    'Debian': {
      ensure_packages([
        'build-essential',
        'libffi-dev',
        'libjpeg-dev',
        'libxml2-dev',
        'libxslt1-dev',
        'libldap2-dev',
        'libssl-dev',
        'zlib1g-dev',
        'libsasl2-dev',
        'libpq-dev',
      ])
    }
    'RedHat': {
      ensure_packages([
        'libffi-devel',
        'libjpeg-turbo-devel',
        'libxml2-devel',
        'libxslt-devel',
        'openldap-devel',
        'openssl-devel',
        'zlib-devel',
      ])
    }
    default: {
      fail('unsupported OS')
    }
  }

  python::virtualenv { $path:
    ensure  => present,
    owner   => $user,
    group   => $group,
    version => 'system',
  }

  Python::Pip {
    ensure     => present,
    virtualenv => $path,
  }

  $pip_dependencies = [
    'django-auth-ldap',
    'hiredis',
    'nydus',
    'psycopg2',
    'python-memcached',
    'python-ldap',
    'redis',
  ]

  python::pip { $pip_dependencies: }

}
