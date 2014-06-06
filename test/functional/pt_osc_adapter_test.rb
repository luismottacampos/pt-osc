require 'test_helper'
require 'yaml'

class PtOscAdapterTest < Test::Unit::TestCase
  class TestConnection < ActiveRecord::Base; end

  def test_connection
    # Test that we can open a connection with the pt_osc adapter
    test_spec = YAML.load_file(Rails.root.join(*%w(.. config database.yml)))['test']
    test_spec['adapter'] = 'pt_osc'

    assert_nothing_raised { TestConnection.establish_connection(test_spec) }
    assert_equal true, TestConnection.connection.in_use
    assert_kind_of ActiveRecord::ConnectionAdapters::PtOscAdapter, TestConnection.connection
  end
end
