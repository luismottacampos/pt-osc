# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pt/osc/version'

Gem::Specification.new do |spec|
  spec.name          = 'pt-osc'
  spec.version       = Pt::Osc::VERSION
  spec.authors       = ['Steve Rice']
  spec.email         = ['steve@pagerduty.com']
  spec.summary       = 'Rails migrations via pt-online-schema-change'
  spec.description   = 'Runs regular Rails/ActiveRecord migrations via the Percona Toolkit pt-online-schema-change tool.'
  spec.homepage      = 'https://github.com/steverice/pt-osc'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'shoulda'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'mocha'

  # For testing using dummy Rails app
  spec.add_development_dependency 'rails', '~> 3.2'
  spec.add_development_dependency 'sqlite3'

  spec.add_runtime_dependency 'activerecord', '~> 3.2'
  spec.add_runtime_dependency 'mysql2'
end
