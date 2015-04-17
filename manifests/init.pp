# == Class: cloudwatchlogs
#
# Configure AWS Cloudwatch Logs on Amazon Linux instances.
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*state_file*]
#   State file for the awslogs agent.
#
# [*logs*]
#   A hash of arrays containg the 'name' & the 'path' of the log file(s) of the
#   log file(s) to be sent to Cloudwatch Logs.
#
# [*region*]
#   The region your EC2 instance is running in.
#
# [*aws_access_key_id*]
#   The Access Key ID from the IAM user that has access to Cloudwatch Logs.
#
# [*aws_secret_access_key*]
#   The Secret Access Key from the IAM user that has access to Cloudwatch Logs.
#
# === Examples
#
#  class { 'cloudwatchlogs':
#    region                => 'eu-west-1',
#    aws_access_key_id     => 'AKIAIOSFODNN7EXAMPLE',
#    aws_secret_access_key => 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
#  }
#
# === Authors
#
# Danny Roberts <danny.roberts@reconnix.com>
# Russ McKendrick <russ.mckendrick@reconnix.com>
#
# === Copyright
#
# Copyright 2015 Danny Roberts & Russ McKendrick
#
class cloudwatchlogs (

  $state_file            = $::cloudwatchlogs::params::state_file,
  $logs                  = $::cloudwatchlogs::params::logs,
  $region                = $::cloudwatchlogs::params::region,
  $aws_access_key_id     = $::cloudwatchlogs::params::aws_access_key_id,
  $aws_secret_access_key = $::cloudwatchlogs::params::aws_secret_access_key,

) inherits cloudwatchlogs::params {

  validate_absolute_path($state_file)
  validate_array($logs)
  validate_string($region)
  validate_string($aws_access_key_id)
  validate_string($aws_secret_access_key)

  case $::operatingsystem {
    'Amazon': {
      package { 'awslogs':
        ensure => 'present',
        before => [
          File['/etc/awslogs/awslogs.conf'],
          File['/etc/awslogs/awscli.conf'],
        ],
      }
      file { '/etc/awslogs/awslogs.conf':
        ensure => 'file',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        content => template('cloudwatchlogs/awslogs.conf.erb'),
      }
      file { '/etc/awslogs/awscli.conf':
        ensure => 'file',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        content => template('cloudwatchlogs/awscli.conf.erb'),
      }
      service { 'awslogs':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => [
          File['/etc/awslogs/awslogs.conf'],
          File['/etc/awslogs/awscli.conf'],
        ],
      }
    }
    /^(Ubuntu|CentOS|RedHat)$/: {
      package { 'wget':
        ensure => 'present',
      }
      exec { 'cloudwatchlogs-wget':
        path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
        command => 'wget -O /usr/local/src/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py',
        unless  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
      }
      file { '/etc/awslogs':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
      file { '/var/awslogs':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
      file { '/var/awslogs/etc':
        ensure  => 'directory',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => File['/var/awslogs'],
        before  => [
          File['/var/awslogs/etc/awslogs.conf'],
          File['/var/awslogs/etc/awscli.conf'],
        ],
      }
      file { '/etc/awslogs/awslogs.conf':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('cloudwatchlogs/awslogs.conf.erb'),
        require => File['/etc/awslogs'],
      }
      file { '/var/awslogs/etc/awslogs.conf':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('cloudwatchlogs/awslogs.conf.erb'),
      }
      file { '/var/awslogs/etc/awscli.conf':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('cloudwatchlogs/awscli.conf.erb'),
      }
      exec { 'cloudwatchlogs-install':
        path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
        command => "python /usr/local/src/awslogs-agent-setup.py -n -r ${region} -c /etc/awslogs/awslogs.conf",
        onlyif  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
        unless  => '[ -d /var/awslogs/bin ]',
        require => File['/etc/awslogs/awslogs.conf'],
        before  => Service['awslogs'],
      }
      service { 'awslogs':
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => [
          File['/var/awslogs/etc/awslogs.conf'],
          File['/var/awslogs/etc/awscli.conf'],
        ],
      }
    }
    default: { fail("The ${module_name} module is not supported on ${::osfamily}/${::operatingsystem}.") }
  }

}
