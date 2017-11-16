if ENV['RUBY_COVERAGE'] == '1'
  require 'simplecov'
  require 'codeclimate-test-reporter'
  SimpleCov.start CodeClimate::TestReporter.configuration.profile
end

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'active_record'
require 'minitest/autorun'
require 'minitest/stub_any_instance'
require 'shoulda'
require 'faker'
require 'mocha'
require 'mocha/mini_test'

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
      if test == :default && field.respond_to?(:type_cast_from_database)
        actual = field.type_cast_from_database(field.default)
      else
        actual = field.send(test)
      end
      assert_equal expected, actual, "Expected #{command} to produce a field of #{test} #{expected}, but it was #{actual}"
    end
  end

  migration.class.send(:remove_method, :change)
end

# @return [Array<Hash>] Fixtures containing :type, :default, :expected_default, and :command for use with sprintf
def add_column_fixtures
  # Rails' "magic" time, for Time columns
  # https://github.com/rails/rails/blob/fcf9b712b1dbbcb8f48644e6f20676ad9480ba66/activerecord/lib/active_record/type/time.rb#L16
  base_date = Time.utc(2000, 1, 1, 0, 0, 0)

  datetime_value = Time.at(Time.now.to_i).utc # Date types we're testing don't have sub-second precision
  date_value = Time.utc(datetime_value.year, datetime_value.month, datetime_value.day)
  rails_time_value = Time.utc(base_date.year, base_date.month, base_date.day, datetime_value.hour, datetime_value.min, datetime_value.sec)

  fixtures = [
    # UPGRADE integer is no longer cast to type
    #https://github.com/rails/rails/commit/4d3e88fc757a1b6f6c468418af01dca677e41edf
    { type: :integer, default: 42, expected_default: 42 },
    { type: :string, default: ['foobar', :bazqux], expected_default: ['foobar', 'bazqux'] },
    { type: :text, default: nil }, # TEXT columns cannot have a default http://dev.mysql.com/doc/refman/5.7/en/blob.html#idm140380410069472
    # UPGRADE integer is no longer cast to type
    #https://github.com/rails/rails/commit/4d3e88fc757a1b6f6c468418af01dca677e41edf
    { type: :float, default: 3.14159, expected_default: 3.14159},
    { type: :datetime, default: datetime_value.strftime('%F %T'), expected_default: datetime_value },
    { type: :time, default: datetime_value.strftime('%T'), expected_default: rails_time_value },
    { type: :date, default: datetime_value.strftime('%F'), expected_default: date_value },
    { type: :binary, default: nil }, # BLOB columns cannot have a default http://dev.mysql.com/doc/refman/5.7/en/blob.html#idm140380410069472
    { type: :boolean, default: [false, true], expected_default: [false, true] }
  ]
  fixtures.map do |fixture|
    fixture[:command] = "add_column :%{table}, :%{column}, :#{fixture[:type]}, default: %<default>p, null: %{nullable}"
    fixture
  end
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

    def self.clear_log
      self.log = []
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

module Kernel
  def quietly_with_deprecation_silenced(&block)
    ActiveSupport::Deprecation.silence do
      quietly_without_deprecation_silenced(&block)
    end
  end
  alias_method_chain :quietly, :deprecation_silenced
end

# UPGRADE
# Assert queries was removed as of rails 4.0.2
class ActiveSupport::TestCase
  def assert_no_queries(&block)
    assert_queries(0, :ignore_none => true, &block)
  end
  def assert_queries(num = 1, options = {})
    ignore_none = options.fetch(:ignore_none) { num == :any }
    ActiveRecord::SQLCounter.clear_log
    yield
  ensure
    the_log = ActiveRecord::SQLCounter.log
    if num == :any
      assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
    else
      mesg = "#{the_log.size} instead of #{num} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
      assert_equal num, the_log.size, mesg
    end
  end
end
