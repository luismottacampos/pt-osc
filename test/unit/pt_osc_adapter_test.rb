require 'test_helper'

class PtOscAdapterTest < Test::Unit::TestCase
  class TestConnection < ActiveRecord::Base; end

  context 'a pt-osc adapter' do
    setup do
      TestConnection.establish_connection(test_spec)
      @adapter = TestConnection.connection
    end

    context '#rename_table' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should 'add a RENAME TO command to the commands hash' do
          table_name = Faker::Lorem.word
          new_table_name = Faker::Lorem.word
          @adapter.rename_table(table_name, new_table_name)
          assert_equal "RENAME TO `#{new_table_name}`", @adapter.send(:get_commands, table_name).first
        end
      end
    end

    context '#add_column' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should 'add an ADD command to the commands hash' do
          table_name = Faker::Lorem.word
          column_name = Faker::Lorem.word
          @adapter.add_column(table_name, column_name, :string, default: 0, null: false)
          assert_equal "ADD `#{column_name}` varchar(255) DEFAULT 0 NOT NULL", @adapter.send(:get_commands, table_name).first
        end
      end
    end

    context '#change_column' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        context 'with an existing table and column' do
          setup do
            @table_name = Faker::Lorem.word
            @column_name = Faker::Lorem.word
            @adapter.create_table @table_name, force: true do |t|
              t.string @column_name
            end
          end

          should 'add a CHANGE command to the commands hash' do
            @adapter.change_column(@table_name, @column_name, :string, default: 0, null: false)
            assert_equal "CHANGE `#{@column_name}` `#{@column_name}` varchar(255) DEFAULT 0 NOT NULL", @adapter.send(:get_commands, @table_name).first
          end
        end
      end
    end

    context '#rename_column' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        context 'with an existing table and column' do
          setup do
            @table_name = Faker::Lorem.word
            @column_name = Faker::Lorem.word
            @adapter.create_table @table_name, force: true do |t|
              t.string @column_name, default: nil
            end
          end

          should 'add a CHANGE command to the commands hash' do
            new_column_name = Faker::Lorem.word
            @adapter.rename_column(@table_name, @column_name, new_column_name)
            assert_equal "CHANGE `#{@column_name}` `#{new_column_name}` varchar(255) DEFAULT NULL", @adapter.send(:get_commands, @table_name).first
          end
        end
      end
    end

    context '#add_command' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should 'add a command without initializing the array' do
          table_name = Faker::Lorem.word
          @adapter.send(:add_command, table_name, 'foo')
          assert_kind_of Array, @adapter.send(:get_commands, table_name)
          assert_equal 1, @adapter.send(:get_commands, table_name).size
          assert_equal 'foo', @adapter.send(:get_commands, table_name).first
        end
      end
    end

    context '#get_commands' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should "return nil for a table that doesn't exist" do
          table_name = Faker::Lorem.word
          assert_nil @adapter.send(:get_commands, table_name)
        end
      end
    end

    context '#get_commands_string' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should "return an empty string for a table that doesn't exist" do
          table_name = Faker::Lorem.word
          assert_equal '', @adapter.send(:get_commands_string, table_name)
        end
      end
    end
  end
end
