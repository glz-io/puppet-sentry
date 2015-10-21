# == Class: sentry
#
# Install Sentry from PyPI and configure an Apache mod_wsgi vhost
#
# === Parameters
#
# admin_email: the admin user's email address; also used as login name (root@localhost)
#
# admin_password: the admin user's password (admin)
#
# beacon: whether to share some data upstream with GetSentry's beacon (False)
#
# db_host: the PostgreSQL database host (localhost)
#
# db_name: the name of the PostgreSQL database to use (sentry)
#
# db_password: the DB user's password (sentry)
#
# db_port: the PostgreSQL database port (5432)
#
# db_user: the user account with which to connect to the database (sentry)
#
# group: UNIX group to own virtualenv, and run background workers (sentry)
#
# ldap_*: LDAP connection details used for creating local user accounts from AD users
#
# max_epm:
#
# max_http_body:
#
# max_stacktrace:
#
# memcached_host: name or IP of memcached server (localhost)
#
# memcached_port: port to use for memcached (11211)
#
# organization: default organization to create, and in which to create new users
#
# path: path into which to install Sentry, and create the virtualenv (/srv/sentry)
#
# percent_limit:
#
# redis_host: name or IP of Redis server (localhost)
#
# redis_port: port to use for Redis (6379)
#
# secret_key: string used to hash cookies (fqdn_rand_string(40))
#
# smtp_host: name or IP of SMTP server (localhost)
#
# ssl_*: Apache SSL controls
#
# team: name of the default team to create and use for new projects
#
# user: UNIX user to own virtualenv, and run background workers (sentry)
#
# version: the Sentry version to install
#
# vhost: the URL at which users will access the Sentry GUI
#
# wsgi_*: mod_wsgi controls
#
# === Authors
# Dan Sajner <dsajner@covermymeds.com>
# Scott Merrill <smerrill@covermymeds.com>
#
# === Copyright
# Copyright 2014 CoverMyMeds, unless otherwise noted
#
# === License
# Released under the terms of the MIT license.  See LICENSE for more details
#
class sentry (
  $admin_email     = $sentry::params::admin_email,
  $admin_password  = $sentry::params::admin_password,
  $beacon          = $sentry::params::beacon,
  $db_host         = $sentry::params::db_host,
  $db_name         = $sentry::params::db_name,
  $db_password     = $sentry::params::db_password,
  $db_port         = $sentry::params::db_port,
  $db_user         = $sentry::params::db_user,
  $group           = $sentry::params::group,
  $ldap_base_ou    = $sentry::params::ldap_base_ou,
  $ldap_domain     = $sentry::params::ldap_domain,
  $ldap_group_base = $sentry::params::ldap_group_base,
  $ldap_group_dn   = $sentry::params::ldap_group_dn,
  $ldap_host       = $sentry::params::ldap_host,
  $ldap_user       = $sentry::params::ldap_user,
  $ldap_password   = $sentry::params::ldap_password,
  $max_epm         = $sentry::params::max_epm,
  $max_http_body   = $sentry::params::max_http_body,
  $max_stacktrace  = $sentry::params::max_stacktrace,
  $memcached_host  = $sentry::params::memcached_host,
  $memcached_port  = $sentry::params::memcached_port,
  $organization    = $sentry::params::organization,
  $path            = $sentry::params::path,
  $percent_limit   = $sentry::params::percent_limit,
  $project         = $sentry::params::project,
  $redis_host      = $sentry::params::redis_host,
  $redis_port      = $sentry::params::redis_port,
  $secret_key      = $sentry::params::secret_key,
  $smtp_host       = $sentry::params::smtp_host,
  $ssl_ca          = $sentry::params::ssl_ca,
  $ssl_chain       = $sentry::params::ssl_chain,
  $ssl_cert        = $sentry::params::ssl_cert,
  $ssl_key         = $sentry::params::ssl_key,
  $team            = $sentry::params::team,
  $user            = $sentry::params::user,
  $version         = $sentry::params::version,
  $vhost           = $sentry::params::vhost,
  $wsgi_processes  = $sentry::params::wsgi_processes,
  $wsgi_threads    = $sentry::params::wsgi_threads,
) inherits ::sentry::params {

  # Install Sentry
  class { 'sentry::install':
    admin_email    => $admin_email,
    admin_password => $admin_password,
    group          => $group,
    organization   => $organization,
    path           => $path,
    project        => $project,
    team           => $team,
    user           => $user,
    version        => $version,
  }

  file { "${path}/sentry.conf":
    ensure  => present,
    content => template('sentry/sentry.conf.erb'),
    notify  => Class['sentry::service'],
  }

  # set up WSGI
  class { 'sentry::wsgi':
    path           => $path,
    ssl_ca         => $ssl_ca,
    ssl_chain      => $ssl_chain,
    ssl_cert       => $ssl_cert,
    ssl_key        => $ssl_key,
    vhost          => $vhost,
    wsgi_processes => $wsgi_processes,
    wsgi_threads   => $wsgi_threads,
    subscribe      => Class['sentry::install'],
  }

  # set up the Sentry background worker(s)
  class { 'sentry::service':
    user      => $user,
    group     => $group,
    path      => $path,
    subscribe => File["${path}/sentry.conf"],
  }

  # Write out a list of "team/project dsn" values to a file.
  # Apache will serve this list and Puppet will consume to set
  # custom facts for each app installed on a server
  file { "${path}/dsn_mapper.py":
    ensure  => present,
    mode    => '0755',
    content => template('sentry/dsn_mapper.py.erb'),
    require => File["${path}/sentry.conf"],
  }

  cron { 'dsn_mapper':
    command => "${path}/bin/python ${path}/dsn_mapper.py",
    user    => root,
    minute  => 5
  }

  # Collect the projects from exported resources
  file { "${path}/create_project.py":
    ensure  => present,
    mode    => '0755',
    content => template('sentry/create_project.py.erb'),
    require => File["${path}/sentry.conf"],
  }

  include sentry::server::collect

}