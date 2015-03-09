require 'test_helper'
require 'yaml'

class MysqlPtOscAdapterTest < Test::Unit::TestCase
  class TestConnection < ActiveRecord::Base; end
  class TestArMigration < ActiveRecord::Migration; end
  class TestPtOscMigration < ActiveRecord::PtOscMigration; end

  def test_connection
    # Test that we can open a connection with the pt_osc adapter
    spec = test_spec
    spec.delete('database') # We don't care whether the database exists

    assert_nothing_raised { TestConnection.establish_connection(spec) }
    assert_equal true, TestConnection.connection.in_use
    assert_kind_of ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter, TestConnection.connection
  end

  def test_activerecord_import_compatibility
    # Test that the adapter can be loaded when using the activerecord-import gem
    assert_nothing_raised { require 'activerecord-import' }
  end

  context 'connected using stubbed pt-osc adapter' do
    setup do
      ActiveRecord::Base.establish_connection(test_spec)
      ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter.stubs(:execute)
    end

    teardown do
      ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter.unstub(:execute)
    end

    context 'an ActiveRecord::Migration' do
      setup do
        @migration = TestArMigration.new
        @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        @migration.stubs(:write)
        @migration.stubs(:announce)
      end

      teardown do
        @migration.unstub(:write, :announce)
      end

      should 'raise a warning when adding columns' do
        add_column_fixtures.each do |fixture|
          fixture_command = sprintf(fixture[:command], table: 'a', column: 'b', default: 0, nullable: true)
          @migration.class.class_eval "def change; #{fixture_command}; end"
          ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter.any_instance.expects(:warn).once
          @migration.migrate(:up)
          @migration.class.send(:remove_method, :change)
        end
      end

      should 'explicitly enable warnings for Rails versions before 4.1' do
        fixture = add_column_fixtures.first
        fixture_command = sprintf(fixture[:command], table: 'a', column: 'b', default: 0, nullable: true)
        @migration.class.class_eval "def change; #{fixture_command}; end"
        %w(3.1 3.1.8 3.2 3.2.20 4.0 4.0.12).each do |rails_version|
          Rails.stubs(:version).returns(rails_version)
          Object.any_instance.expects(:enable_warnings).once.yields
          silence_warnings { @migration.migrate(:up) }
        end
        %w(4.1 4.1.9 4.2 4.2.0.beta4 4.2.1 5 5.0).each do |rails_version|
          Rails.stubs(:version).returns(rails_version)
          Object.any_instance.expects(:enable_warnings).never
          silence_warnings { @migration.migrate(:up) }
        end
        @migration.class.send(:remove_method, :change)
      end
    end

    context 'an ActiveRecord::PtOscMigration' do
      setup do
        @migration = TestPtOscMigration.new
        @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        @migration.stubs(:write)
        @migration.stubs(:announce)
      end

      teardown do
        @migration.unstub(:write, :announce)
      end

      should 'not raise a warning when adding columns' do
        add_column_fixtures.each do |fixture|
          fixture_command = sprintf(fixture[:command], table: 'a', column: 'b', default: 0, nullable: true)
          @migration.class.class_eval "def change; #{fixture_command}; end"
          ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter.any_instance.expects(:warn).never
          @migration.migrate(:up)
          @migration.class.send(:remove_method, :change)
        end
      end
    end
  end
end
