require 'test_helper'
require 'yaml'

class MysqlPtOscAdapterTest < Test::Unit::TestCase
  class TestConnection < ActiveRecord::Base; end

  def test_connection
    # Test that we can open a connection with the pt_osc adapter
    spec = test_spec
    spec.delete('database') # We don't care whether the database exists

    assert_nothing_raised { TestConnection.establish_connection(spec) }
    assert_equal true, TestConnection.connection.in_use
    assert_kind_of ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter, TestConnection.connection
  end
end
