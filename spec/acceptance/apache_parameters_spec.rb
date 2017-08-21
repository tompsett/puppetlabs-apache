require 'spec_helper_acceptance'
require_relative './version.rb'

describe 'apache parameters' do

  # Currently this test only does something on FreeBSD.
  # Remove the first 4 tests - They are freebsd whcih isnt supported line 7 - 31
  describe 'default_confd_files => false', :audit_delete => true do
    it 'doesnt do anything' do
      pp = "class { 'apache': default_confd_files => false }"
      apply_manifest(pp, :catch_failures => true)
    end

    if fact('osfamily') == 'FreeBSD'
      describe file("#{$confd_dir}/no-accf.conf.erb") do
        it { is_expected.not_to be_file }
      end
    end
  end

  describe 'default_confd_files => true', :audit_delete => true do
    it 'copies conf.d files' do
      pp = "class { 'apache': default_confd_files => true }"
      apply_manifest(pp, :catch_failures => true)
    end

    if fact('osfamily') == 'FreeBSD'
      describe file("#{$confd_dir}/no-accf.conf.erb") do
        it { is_expected.to be_file }
      end
    end
  end

  # Should be :unit test, not checking os, only checks file exists and contents 34-44, :high
  describe 'when set adds a listen statement', :audit_risk => :high, :audit_layer => :unit do
    it 'applys cleanly' do
      pp = "class { 'apache': ip => '10.1.1.1', service_ensure => stopped }"
      apply_manifest(pp, :catch_failures => true)
    end

    describe file($ports_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'Listen 10.1.1.1' }
    end
  end

# :acceptance test & refactor, :high - Address pending section
  describe 'service tests => true', :audit_risk => :high, :audit_layer => :acceptance, audit_refactor => true do
    it 'starts the service' do
      pp = <<-EOS
        class { 'apache':
          service_enable => true,
          service_manage => true,
          service_ensure => running,
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe service($service_name) do
      it { is_expected.to be_running }
      if (fact('operatingsystem') == 'Debian' && fact('operatingsystemmajrelease') == '8')
        pending 'Should be enabled - Bug 760616 on Debian 8'
      else
        it { is_expected.to be_enabled }
      end
    end
  end

  # :acceptance test & refactor, :high - Address pending section
  describe 'service tests => false', :audit_risk => :high, :audit_layer => :acceptance, :audit_refactor=> true do
    it 'stops the service' do
      pp = <<-EOS
        class { 'apache':
          service_enable => false,
          service_ensure => stopped,
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe service($service_name) do
      it { is_expected.not_to be_running }
      if (fact('operatingsystem') == 'Debian' && fact('operatingsystemmajrelease') == '8')
        pending 'Should be enabled - Bug 760616 on Debian 8'
      else
        it { is_expected.not_to be_enabled }
      end
    end
  end

  # :acceptance test & refactor, :high - Adddress pending section, we shoudl check the erorr that is returned  91 - 111
  describe 'service manage => false', :audit_risk => :high, :audit_layer => :acceptance, :audit_refactor => true do
    it 'we dont manage the service, so it shouldnt start the service' do
      pp = <<-EOS
        class { 'apache':
          service_enable => true,
          service_manage => false,
          service_ensure => true,
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe service($service_name) do
      it { is_expected.not_to be_running }
      if (fact('operatingsystem') == 'Debian' && fact('operatingsystemmajrelease') == '8')
        pending 'Should be enabled - Bug 760616 on Debian 8'
      else
        it { is_expected.not_to be_enabled }
      end
    end
  end

# :acceptance, :high, check that this purging needs to be limited to debian 114-160
  describe 'purge parameters => false', :audit_risk => :high, :audit_layer => :acceptance, :audit_refactor => true do
    it 'applies cleanly' do
      pp = <<-EOS
        class { 'apache':
          purge_configs   => false,
          purge_vhost_dir => false,
          vhost_dir       => "#{$confd_dir}.vhosts"
        }
      EOS
      shell("touch #{$confd_dir}/test.conf")
      shell("mkdir -p #{$confd_dir}.vhosts && touch #{$confd_dir}.vhosts/test.conf")
      apply_manifest(pp, :catch_failures => true)
    end

    # Ensure the files didn't disappear.
    describe file("#{$confd_dir}/test.conf") do
      it { is_expected.to be_file }
    end
    describe file("#{$confd_dir}.vhosts/test.conf") do
      it { is_expected.to be_file }
    end
  end

  if fact('osfamily') != 'Debian'
    describe 'purge parameters => true', :audit_risk => :high, :audit_layer => :acceptance, :audit_refactor => true do
      it 'applies cleanly' do
        pp = <<-EOS
          class { 'apache':
            purge_configs   => true,
            purge_vhost_dir => true,
            vhost_dir       => "#{$confd_dir}.vhosts"
          }
        EOS
        shell("touch #{$confd_dir}/test.conf")
        shell("mkdir -p #{$confd_dir}.vhosts && touch #{$confd_dir}.vhosts/test.conf")
        apply_manifest(pp, :catch_failures => true)
      end

      # File should be gone
      describe file("#{$confd_dir}/test.conf") do
        it { is_expected.not_to be_file }
      end
      describe file("#{$confd_dir}.vhosts/test.conf") do
        it { is_expected.not_to be_file }
      end
    end
  end

  # :unit, :high
  describe 'serveradmin', :audit_risk => :high, :audit_layer => :unit do
    it 'applies cleanly' do
      pp = "class { 'apache': serveradmin => 'test@example.com' }"
      apply_manifest(pp, :catch_failures => true)
    end

    describe file($vhost) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'ServerAdmin test@example.com' }
    end
  end

# :unit, :medium - All of the checking the config file contents
  describe 'sendfile', :audit_risk => :medium, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': sendfile => 'On' }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'EnableSendfile On' }
    end

    describe 'setup', :audit_risk => :medium, :audit_layer => :unit do
      it 'applies cleanly' do
        pp = "class { 'apache': sendfile => 'Off' }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'Sendfile Off' }
    end
  end


  describe 'error_documents', :audit_risk => :medium, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': error_documents => true }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'Alias /error/' }
    end
  end

  describe 'timeout', :audit_risk => :medium, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': timeout => '1234' }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'Timeout 1234' }
    end
  end

 # Dont think this is in the right place - Its checking mime file contents
  describe 'httpd_dir', :audit_refactor do
    describe 'setup' do
      it 'applies cleanly' do
        pp = <<-EOS
          class { 'apache': httpd_dir => '/tmp', service_ensure => stopped }
          include 'apache::mod::mime'
        EOS
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file("#{$mod_dir}/mime.conf") do
      it { is_expected.to be_file }
      it { is_expected.to contain 'AddLanguage eo .eo' }
    end
  end


  # Does the bug still exist? check on ubuntu or sles
  # If bug dosnt exist it can be a :unit test, otherwise an :acceptance test, :medium
  describe 'http_protocol_options', :audit_risk => :medium, :audit_layer => :unit?, :audit_refactor => true do
    # Actually >= 2.4.24, but the minor version is not provided
    # https://bugs.launchpad.net/ubuntu/+source/apache2/2.4.7-1ubuntu4.15
    # basically versions of the ubuntu or sles  apache package cause issue
    if $apache_version >= '2.4' && fact('operatingsystem') !~ /Ubuntu|SLES/
      describe 'setup' do
        it 'applies cleanly' do
          pp = "class { 'apache': http_protocol_options => 'Unsafe RegisteredMethods Require1.0'}"
          apply_manifest(pp, :catch_failures => true)
        end
      end

      describe file($conf_file) do
        it { is_expected.to be_file }
        it { is_expected.to contain 'HttpProtocolOptions Unsafe RegisteredMethods Require1.0' }
      end
    end
  end

# :unit, :medium
  describe 'server_root', :audit_risk => :medium, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': server_root => '/tmp/root', service_ensure => stopped }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'ServerRoot "/tmp/root"' }
    end
  end


# This is :high, confdir is important, things cant start, :unit if I can - with the apache_version
  describe 'confd_dir', :audit_risk => :high, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': confd_dir => '/tmp/root', service_ensure => stopped, use_optional_includes => true }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    if $apache_version == '2.4'
      describe file($conf_file) do
        it { is_expected.to be_file }
        it { is_expected.to contain 'IncludeOptional "/tmp/root/*.conf"' }
      end
    else
      describe file($conf_file) do
        it { is_expected.to be_file }
        it { is_expected.to contain 'Include "/tmp/root/*.conf"' }
      end
    end
  end

# Could be a :unit test, :high
  describe 'conf_template', :audit_risk => :high, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': conf_template => 'another/test.conf.erb', service_ensure => stopped }"
        shell("mkdir -p #{default['distmoduledir']}/another/templates")
        shell("echo 'testcontent' >> #{default['distmoduledir']}/another/templates/test.conf.erb")
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'testcontent' }
    end
  end

# :high, :unit
  describe 'servername', :audit_risk => :high, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': servername => 'test.server', service_ensure => stopped }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'ServerName "test.server"' }
    end
  end

# Could be :acceptance due to OS dependency, creating user. :high
  describe 'user', :audit_risk => :high, :audit_layer => :acceptance do
    describe 'setup' do
      it 'applies cleanly' do
        pp = <<-EOS
          class { 'apache':
            manage_user  => true,
            manage_group => true,
            user         => 'testweb',
            group        => 'testweb',
          }
        EOS
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe user('testweb') do
      it { is_expected.to exist }
      it { is_expected.to belong_to_group 'testweb' }
    end

    describe group('testweb') do
      it { is_expected.to exist }
    end
  end

# :unit, med
  describe 'logformats', :audit_risk => :medium, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = <<-EOS
          class { 'apache':
            log_formats => {
              'vhost_common'   => '%v %h %l %u %t \\\"%r\\\" %>s %b',
              'vhost_combined' => '%v %h %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-agent}i\\\"',
            }
          }
        EOS
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'LogFormat "%v %h %l %u %t \"%r\" %>s %b" vhost_common' }
      it { is_expected.to contain 'LogFormat "%v %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" vhost_combined' }
    end
  end

# :high, :unit
  describe 'keepalive', :audit_risk => :high, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': keepalive => 'Off', keepalive_timeout => '30', max_keepalive_requests => '200' }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'KeepAlive Off' }
      it { is_expected.to contain 'KeepAliveTimeout 30' }
      it { is_expected.to contain 'MaxKeepAliveRequests 200' }
    end
  end

# :unit, :low
  describe 'limitrequestfieldsize', :audit_risk => :low, :audit_layer => :unit do
    describe 'setup' do
      it 'applies cleanly' do
        pp = "class { 'apache': limitreqfieldsize => '16830' }"
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'LimitRequestFieldSize 16830' }
    end
  end

# :acceptance, does it need to be limited to OS, med
  describe 'logging', :audit_risk => :medium, :audit_layer => :unit, :audit_refactor => true do
    describe 'setup' do
      it 'applies cleanly' do
        pp = <<-EOS
          if $::osfamily == 'RedHat' and "$::selinux" == "true" {
            $semanage_package = $::operatingsystemmajrelease ? {
              '5'     => 'policycoreutils',
              default => 'policycoreutils-python',
            }

            package { $semanage_package: ensure => installed }
            exec { 'set_apache_defaults':
              command => 'semanage fcontext -a -t httpd_log_t "/apache_spec(/.*)?"',
              path    => '/bin:/usr/bin/:/sbin:/usr/sbin',
              require => Package[$semanage_package],
            }
            exec { 'restorecon_apache':
              command => 'restorecon -Rv /apache_spec',
              path    => '/bin:/usr/bin/:/sbin:/usr/sbin',
              before  => Service['httpd'],
              require => Class['apache'],
            }
          }
          file { '/apache_spec': ensure => directory, }
          class { 'apache': logroot => '/apache_spec' }
        EOS
        apply_manifest(pp, :catch_failures => true)
      end
    end

    describe file("/apache_spec/#{$error_log}") do
      it { is_expected.to be_file }
    end
  end

# - Move all ports test together (up the file) :unit, :medium
  describe 'ports_file', :audit_risk => :medium, :audit_layer => :unit, :audit_refactor => true do
    it 'applys cleanly' do
      pp = <<-EOS
        file { '/apache_spec': ensure => directory, }
        class { 'apache':
          ports_file     => '/apache_spec/ports_file',
          ip             => '10.1.1.1',
          service_ensure => stopped
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe file('/apache_spec/ports_file') do
      it { is_expected.to be_file }
      it { is_expected.to contain 'Listen 10.1.1.1' }
    end
  end

# :unit, med
  describe 'server_tokens', :audit_risk => :medium, :audit_layer => :unit do
    it 'applys cleanly' do
      pp = <<-EOS
        class { 'apache':
          server_tokens  => 'Minor',
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'ServerTokens Minor' }
    end
  end

# :unit, :medium
  describe 'server_signature', :audit_risk => :medium, :audit_layer => :unit do
    it 'applys cleanly' do
      pp = <<-EOS
        class { 'apache':
          server_signature  => 'testsig',
          service_ensure    => stopped,
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'ServerSignature testsig' }
    end
  end

# :unit, med
  describe 'trace_enable', :audit_risk => :medium, :audit_layer => :unit do
    it 'applys cleanly' do
      pp = <<-EOS
        class { 'apache':
          trace_enable  => 'Off',
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'TraceEnable Off' }
    end
  end

  describe 'file_e_tag', :audit_risk => :medium, :audit_layer => :unit do
    it 'applys cleanly' do
      pp = <<-EOS
        class { 'apache':
          file_e_tag  => 'None',
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe file($conf_file) do
      it { is_expected.to be_file }
      it { is_expected.to contain 'FileETag None' }
    end
  end

# :high, :acceptance
  describe 'package_ensure', :audit_risk => :high, :audit_layer => :acceptance do
    it 'applys cleanly' do
      pp = <<-EOS
        class { 'apache':
          package_ensure  => present,
        }
      EOS
      apply_manifest(pp, :catch_failures => true)
    end

    describe package($package_name) do
      it { is_expected.to be_installed }
    end
  end
end
