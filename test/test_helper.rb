require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'test/unit'
require 'shoulda'
require 'faker'
require 'mocha'

Rails.backtrace_cleaner.remove_silencers!

def test_spec(key = 'test')
  test_spec = YAML.load_file(Rails.root.join(*%w(.. config database.yml)))[key]
  test_spec['adapter'] = 'mysql_pt_osc'
  test_spec
end

def migrate_and_test_field(command, migration, table_name, field_name, assertions = {})
  migration.class.class_eval "def change; #{command}; end"

  migration.stubs(:write)
  migration.stubs(:announce)
  migration.migrate(:up)
  migration.unstub(:write, :announce)

  field = ActiveRecord::Base.connection.columns(table_name).find { |f| f.name == field_name }
  if assertions.delete(:exists) == false
    assert_nil field
  else
    assert_not_nil field
    assert_equal field_name, field.name
    assertions.each do |test, expected|
      actual = field.send(test)
      assert_equal expected, actual, "Expected #{command} to produce a field of #{test} #{expected}, but it was #{actual}"
    end
  end

  migration.class.send(:remove_method, :change)
end

# SQLCounter is part of ActiveRecord but is not distributed with the gem (used for internal tests only)
# see https://github.com/rails/rails/blob/3-2-stable/activerecord/test/cases/helper.rb#L59
module ActiveRecord
  class SQLCounter
    cattr_accessor :ignored_sql
    self.ignored_sql = [/^PRAGMA (?!(table_info))/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^SHOW max_identifier_length/, /^BEGIN/, /^COMMIT/]

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL.  This ignored SQL is for Oracle.
    ignored_sql.concat [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im]

    cattr_accessor :log
    self.log = []

    attr_reader :ignore

    def initialize(ignore = self.class.ignored_sql)
      @ignore   = ignore
    end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      return if 'CACHE' == values[:name] || ignore.any? { |x| x =~ sql }
      self.class.log << sql
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
end
