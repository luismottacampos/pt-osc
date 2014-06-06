# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'test/unit'

Rails.backtrace_cleaner.remove_silencers!

def test_spec
  test_spec = YAML.load_file(Rails.root.join(*%w(.. config database.yml)))['test']
  test_spec['adapter'] = 'pt_osc'
  test_spec
end
