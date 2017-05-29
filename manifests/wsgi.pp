# == Class sentry::wsgi
#
# Install an Apache virtual host, configure mod_wsgi,
# and run Sentry.  HTTPS support is optional.
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
# Scott Merrill <smerrill@covermymeds.com>
#
# === Copyright
#
# Copyright 2015 CoverMyMeds
#
# === Params
#
# @param apache_enabled Whether to enable/start the apache service
# @param path the virtualenv path for your Sentry installation
# @param publish_dsns whether or not to make each Sentry application's DSN accessible via http(s)
# @param ssl whether or not to enable SSL support
# @param ssl_ca the SSL CA file to use
# @param ssl_chain the SSL chain file to use
# @param ssl_cert the SSL public certificate to use
# @param ssl_key the SSL private key to use
# @param vhost the hostname at which Sentry will be accessible
# @param wsgi_processes the number of mod_wsgi processes to use
# @param wsgi_threads the number of mod_wsgi threads to use
#
class sentry::wsgi (
  $path                   = $sentry::path,
  $publish_dsns           = true,
  $ssl                    = true,
  $ssl_ca                 = $sentry::ssl_ca,
  $ssl_chain              = $sentry::ssl_chain,
  $ssl_cert               = $sentry::ssl_cert,
  $ssl_key                = $sentry::ssl_key,
  $vhost                  = $sentry::vhost,
  $wsgi_processes         = $sentry::wsgi_processes,
  $wsgi_threads           = $sentry::wsgi_threads,
  $wsgi_user              = $sentry::wsgi_user,
  $wsgi_group             = $sentry::wsgi_group,
) {

  # this is a null declaration to ensure that the Apache module
  # doesn't try to helpfully create the docroot.
  #file{ $path: }

  include apache::mod::alias
  include apache::mod::deflate
  include apache::mod::rewrite
  include apache::mod::wsgi

  # we need to get the Python version in the form 'Python27' for use
  # in the `python-path` option of mod_wsgi
  $python = regsubst( $::python_version, '(\d)\.(\d).+', 'python\1.\2' )
  $python_path = "${path}/lib/${python}/site-packages/"

  $wsgi_options_hash = {
      user         => $wsgi_user,
      group        => $wsgi_group,
      processes    => $wsgi_processes,
      threads      => $wsgi_threads,
      display-name => 'wsgi_sentry',
      python-path  => $python_path,
  }

  # If desired, each application's DSN can be published at
  #   http(s)://your.sentry.server/dsn/app_name
  # The DSNs so published are not restricted in any way,
  # which means that anyone may access them.
  #
  # This may be used to allow applications to look up their DSN
  # automatically.  See the /examples/ directory for more.
  if $publish_dsns {
    $aliases = [
      {
        aliasmatch => '^/dsn/([^/]+)$',
        path => "${path}/dsn/\$1",
      },
    ]
  } else {
    $aliases = undef
  }

  #lint:ignore:arrow_alignment
  apache::vhost { 'sentry':
    access_log_file             => 'sentry.log',
    access_log_format           => 'combined',
    aliases                     => $aliases,
    docroot                     => $path,
    error_log_file              => 'sentry-e.log',
    manage_docroot              => false,
    port                        => '443',
    servername                  => $vhost,
    ssl                         => $ssl,
    ssl_ca                      => $ssl_ca,
    ssl_chain                   => $ssl_chain,
    ssl_cert                    => $ssl_cert,
    ssl_key                     => $ssl_key,
    wsgi_daemon_process         => 'wsgi_sentry',
    wsgi_daemon_process_options => $wsgi_options_hash,
    wsgi_pass_authorization     => 'On',
    wsgi_process_group          => 'wsgi_sentry',
    wsgi_script_aliases         => { '/' => "${path}/app_init.wsgi", },
  }
  #lint:endignore

  file { "${path}/app_init.wsgi":
    ensure  => present,
    content => template('sentry/app_init.wsgi.erb'),
  }

}
