# Class: confluence::install
#
# $HeadURL: svn+ssh://repo02.cambridge.manhunt.net/SysEng/Puppet/trunk/etc/puppet/modules/confluence/manifests/install.pp $
#
# $Id: init.pp 1342 2013-04-03 10:55:00 rviswakumar $
#
# This module manages confluence
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class confluence::install (
  $cversion    = "5.1",
  $install_dir = "/opt/confluence",
  $tomcat_apps = "/var/lib/tomcat6/webapps",
  $tomcat_xml  = "/etc/tomcat6/Catalina/localhost",
  # MySQL Info
  $dbhost      = "localhost",
  $dbname      = "confluencedb",
  $dbuser      = "mhconfluence",
  $dbpass      = "kjd73hn",
  $dbport      = "3306",
  $dbtype      = "InnoDB",) {
  Exec {
    cwd  => '/tmp',
    path => split($path, ":"),
  }

  exec { 'wget-conf':
    creates => "/tmp/atlassian-confluence-${cversion}-war.tar.gz",
    command => "wget http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${cversion}-war.tar.gz",
  }

  file { "$install_dir":
    ensure  => directory,
    owner   => 'tomcat',
    group   => 'tomcat',
    mode    => '0664',
    require => Exec['wget-conf'],
  }

  file { "${install_dir}/home":
    ensure  => directory,
    owner   => 'tomcat',
    group   => 'tomcat',
    mode    => '0775',
    require => Exec['wget-conf'],
  }

  exec { 'untar-conf':
    cwd     => "$install_dir",
    creates => "/${install_dir}/confluence-${cversion}/build.sh",
    command => "tar zxpf /tmp/atlassian-confluence-${cversion}-war.tar.gz",
    require => File["$install_dir"]
  }

  # Adds the MySQL JDBC plugin
  file { "${install_dir}/confluence-${cversion}/confluence/WEB-INF/lib/mysql-connector-java-5.1.24-bin.jar":
    ensure  => present,
    source  => "puppet:///modules/${module_name}/mysql-connector-java-5.1.24-bin.jar",
    notify  => Exec['build-conf'],
    require => Exec['untar-conf'],
  }

  file { "${install_dir}/confluence-${cversion}/confluence/WEB-INF/classes/confluence-init.properties":
    ensure  => present,
    content => template("${module_name}/confluence-init.properties.erb"),
    require => Exec['untar-conf'],
  }

  exec { 'build-conf':
    cwd     => "/${install_dir}/confluence-${cversion}/",
    creates => "/${install_dir}/confluence-${cversion}/dist/confluence-${cversion}.war",
    command => "bash /${install_dir}/confluence-${cversion}/build.sh",
    require => File["${install_dir}/confluence-${cversion}/confluence/WEB-INF/classes/confluence-init.properties"],
  }

  file { "${tomcat_apps}/confluence.jar":
    ensure  => present,
    source  => "file:///${install_dir}/confluence-${cversion}/dist/confluence-${cversion}.war",
    require => Exec['build-conf'],
  }

  file { "${tomcat_xml}/confluence.xml":
    ensure  => present,
    content => template("${module_name}/confluence.xml.erb"),
    require => Exec['build-conf'],
    notify  => Service['tomcat6'],
  }

  # This file currently contains a hash of the eval license, so I'm leaving it unmanaged for now
  #file { "${install_dir}/home/confluence.cfg.xml":
  #  ensure  => present,
  #  owner   => 'tomcat',
  #  group   => 'tomcat',
  #  mode    => '0644',
  #  content => template("${module_name}/confluence.cfg.xml.erb"),
  #}
}
