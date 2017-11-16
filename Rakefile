require 'bundler/gem_tasks'
require 'rake/testtask'
require 'active_record'
require 'yaml'

Rake::TestTask.new do |t|
  t.libs.push 'test'
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Run tests'
task :default => :test

namespace :db do
  task :test_create do
    if ActiveRecord::VERSION::MAJOR == 3
      load 'active_record/railties/databases.rake'
      test_spec = YAML.load_file('./test/config/database.yml')['test']
      test_spec['adapter'] = 'mysql2'
      create_database(test_spec)
    else
      include ActiveRecord::Tasks
      DatabaseTasks.env = :test
      ActiveRecord::Base.configurations = YAML.load_file('./test/config/database.yml')
      DatabaseTasks.root = File.expand_path(__dir__)
      DatabaseTasks.create_current('test')
    end
  end
end
