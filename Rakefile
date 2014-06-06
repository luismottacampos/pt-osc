require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs.push 'test'
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Run tests'
task :default => :test

load 'active_record/railties/databases.rake'

namespace :db do
  task :test_create do
    test_spec = YAML.load_file('./test/config/database.yml')['test']
    test_spec['adapter'] = 'mysql2'
    create_database(test_spec)
  end
end
