source 'https://rubygems.org'

# Specify your gem's dependencies in pt-osc.gemspec
gemspec

rails_version = ENV["RAILS_VERSION"] || "4.2.6"

gem 'rails', rails_version

# unable to add into gemspec since it doesn't support AR 3.x
gem 'protected_attributes' unless rails_version =~ /\A3/

group :test do
  gem 'codeclimate-test-reporter', require: nil
end
