class sfx {
  concat{'/tmp/sfx.meta':
    ensure => present,
    owner => 'root',
    group => 'root',
    mode => '0644'
  }

  $metaKV = hiera_hash('sfx-meta')
  $metaKVKeys = keys($metaKV)
  updateSFXMeta{$metaKVKeys:}
  #$config_string = 'default_value'
  $otel_group = lookup('otel_group', {'default_value' => 'NO_GROUP'})
  notify { "stdout: otel group is ${otel_group}": }
  $config_string = "--config=/etc/otelcol-contrib/otelfiles/base.yaml --config=/etc/otelcol-contrib/otelfiles/cpu.yaml --config=/etc/otelcol-contrib/otelfiles/exporters.yaml --config=/etc/otelcol-contrib/otelfiles/extensions.yaml --config=/etc/otelcol-contrib/otelfiles/processors.yaml"
  
  file {
    'test_hiera':
      path => '/tmp/test_hiera_file',
      mode => '0777',
      #content => lookup('otel_group'),
  }
  
  service { 'otelcol-contrib':
    enable  => true,
    ensure => running,
    #subscribe => File['/etc/otelcol-contrib/otelcol-contrib.conf'],
    require => [
    File['/etc/otelcol-contrib/otelfiles/base.yaml'],
    File['/etc/otelcol-contrib/otelfiles/cpu.yaml'],
    File['/etc/otelcol-contrib/otelfiles/exporters.yaml'],
    File['/etc/otelcol-contrib/otelfiles/extensions.yaml'],
    File['/etc/otelcol-contrib/otelfiles/processors.yaml'],
    File['/etc/otelcol-contrib/otelcol-contrib.conf'],
  ],
  }
  
  file { '/etc/otelcol-contrib/otelfiles':
    ensure  => 'directory',
    recurse => true,
    mode    => '0755',  # Optional: Set the desired permissions
    owner   => 'root',  # Optional: Set the desired owner
    group   => 'root', # Optional: Set the desired group
  }
  
  file { '/etc/otelcol-contrib/otelfiles/scripts':
    ensure  => 'directory',
    mode    => '0755',  # Optional: Set the desired permissions
    owner   => 'root',  # Optional: Set the desired owner
    group   => 'root', # Optional: Set the desired group
  }

file { '/etc/otelcol-contrib/otelfiles/scripts/build_config_string.sh':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/build_config_string.sh",
    ],
    mode => '0755'
  }

  
  file { '/etc/otelcol-contrib/otelfiles/scripts/build_otel_config.sh':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/build_otel_config.sh",
    ],
    mode => '0755'
  }
  
  
 # file { '/etc/otelcol-contrib/otelfiles/groups.out':
  #  ensure => 'present',
  #  source => [
   #     "puppet:///modules/sfx/groups.out",
  #  ],
  #  mode => '0755',
  #}
  
  file { '/etc/otelcol-contrib/otelfiles/base.yaml':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/custom/base/${::hostname}.yaml",
        "puppet:///modules/sfx/custom/base/groups/${otel_group}.yaml",
        'puppet:///modules/sfx/base/base.yaml'
    ],
    notify => Service['otelcol-contrib'],
    before => Service['otelcol-contrib'],
  }
  
  file { '/etc/otelcol-contrib/otelfiles/cpu.yaml':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/custom/cpu/${::hostname}.yaml",
        "puppet:///modules/sfx/custom/cpu/groups/${otel_group}.yaml",
        'puppet:///modules/sfx/base/cpu.yaml'
    ],
    notify => Service['otelcol-contrib'],
    before => Service['otelcol-contrib'],
  }
  
  file { '/etc/otelcol-contrib/otelfiles/exporters.yaml':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/custom/exporters/${::hostname}.yaml",
        "puppet:///modules/sfx/custom/exporter/groups/${otel_group}.yaml",
        'puppet:///modules/sfx/base/exporters.yaml'
    ],
    notify => Service['otelcol-contrib'],
    before => Service['otelcol-contrib'],
  }
  
  file { '/etc/otelcol-contrib/otelfiles/extensions.yaml':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/custom/extensions/${::hostname}.yaml",
        #"puppet:///modules/sfx/custom/extensions/groups/${::otel_group}.yaml",
        'puppet:///modules/sfx/custom/extensions/groups/${otel_group}.yaml',
        'puppet:///modules/sfx/base/extensions.yaml'
    ],
    notify => Service['otelcol-contrib'],
    before => Service['otelcol-contrib'],
  }
  
  file { '/etc/otelcol-contrib/otelfiles/processors.yaml':
    ensure => 'present',
    source => [
        "puppet:///modules/sfx/custom/processors/${::hostname}.yaml",
        "puppet:///modules/sfx/custom/processors/groups/${otel_group}.yaml",
        'puppet:///modules/sfx/base/processors.yaml'
    ],
    notify => Service['otelcol-contrib'],
    before => Service['otelcol-contrib'],
  }
  
  notify { "running terraform if statement": }
  if $otel_group == 'terraform' {
    file { '/etc/otelcol-contrib/otelfiles/terraform.yaml':
        ensure => 'present',
        source => [
            "puppet:///modules/sfx/custom/terraform/terraform.yaml"
        ],
        notify => Service['otelcol-contrib'],
        before => [
        Service['otelcol-contrib'],
        File['/etc/otelcol-contrib/otelcol-contrib.conf'],
        ],
    }
    
    #$config_string = generate('/etc/otelcol-contrib/otelfiles/scripts/build_config_string.sh')
    #$config_string += " --config=/etc/otelcol-contrib/otelfiles/terraform.yaml"
    #$config_string = concat($config_string, ' --config=/etc/otelcol-contrib/otelfiles/terraform.yaml')
    $new_config_string = "${config_string} --config=/etc/otelcol-contrib/otelfiles/terraform.yaml"

    notify { "otel group is tf:  ${new_config_string}": }
    
  } else {
  

    file { '/etc/otelcol-contrib/otelfiles/terraform.yaml':
        ensure => 'absent',    
        before => [
        Service['otelcol-contrib'],
        File['/etc/otelcol-contrib/otelcol-contrib.conf'],
        ],
    }
    
    #$config_string = generate('/etc/otelcol-contrib/otelfiles/scripts/build_config_string.sh')
    notify { "otel group is not tf:  ${new_config_string}": }
    $new_config_string=$config_string
  }    
  
 # exec { 'run_build_config':
  #    command => '/etc/otelcol-contrib/otelfiles/scripts/build_otel_config.sh',
   # }
   
   # $config_string = generate('/etc/otelcol-contrib/otelfiles/scripts/build_config_string.sh')
    #notify { "stdout: hello ${config_string}": }
  
  
  notify { "running otelcol-contrib.conf": }
  file { '/etc/otelcol-contrib/otelcol-contrib.conf':
    #source => [
     #   "puppet:///modules/sfx/otelcol-contrib.conf",
    #],
    content => template('sfx/otelcol-contrib.conf.erb'),
    ensure => 'present',
    mode => '0755',
    #audit => 'mtime',
    notify => Service['otelcol-contrib'],
    before => [
        Service['otelcol-contrib'],
    ],
  }
   
   
}
    

define updateSfxMeta {

  # get the hashes again because outside vars aren't visible here
  $metaKV = hiera_hash('sfx-meta')

  # $name is the key $metaKVValue is the value
  $metaKVValue = $metaKV[$name]

  #notify { "Key is $name": }
  #notify { "Value is $metaKVValue": }

  concat::fragment{"sfx_meta_$name":
    target => '/tmp/sfx.meta',
    content => "${name}=${$metaKVValue}\n"
  }
  

}

  }
  

}
