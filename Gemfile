source 'https://rubygems.org'

# Specify your gem's dependencies in pt-osc.gemspec
gemspec

rails_version = ENV["RAILS_VERSION"] || '4.2.8'

gem 'rails', rails_version
gem 'activerecord', rails_version

# Rails 3 requires this version
gem 'mysql2', '~> 0.3.10' if rails_version.to_i == 3

group :test do
  gem 'testrbl'
  gem 'minitest'
  gem 'test-unit'
  gem 'codeclimate-test-reporter', require: false
end
