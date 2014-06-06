# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'test/unit'
require 'shoulda'
require 'faker'
require 'mocha'

Rails.backtrace_cleaner.remove_silencers!

def test_spec
  test_spec = YAML.load_file(Rails.root.join(*%w(.. config database.yml)))['test']
  test_spec['adapter'] = 'pt_osc'
  test_spec
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
