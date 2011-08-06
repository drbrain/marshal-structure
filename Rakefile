# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :git
Hoe.plugin :isolate
Hoe.plugin :minitest

Hoe.spec 'marshal-structure' do
  developer 'Eric Hodel', 'drbrain@segment7.net'

  rdoc_locations << 'docs.seattlerb.org:/data/www/docs.seattlerb.org/marshal-structure/'

  self.readme_file = 'README.rdoc'
  self.extra_rdoc_files << 'README.rdoc' # HACK fix in Hoe

  if respond_to? :isolate_dir= then # HACK Hoe issue #7
    self.isolate_dir = 'tmp/isolate'
  else
    warn 'please: gem install isolate'
  end

  extra_dev_deps << ['ben_string', '~> 1']
end

# vim: syntax=ruby
