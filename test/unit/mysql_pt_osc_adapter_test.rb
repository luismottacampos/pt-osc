require 'test_helper'

class MysqlPtOscAdapterTest < Test::Unit::TestCase
  class TestConnection < ActiveRecord::Base; end

  context 'a pt-osc adapter' do
    setup do
      TestConnection.establish_connection(test_spec)
      @adapter = TestConnection.connection
      # Silence warnings about not using an ActiveRecord::PtOscMigration
      # @see Kernel#suppress_warnings
      @original_verbosity, $VERBOSE = $VERBOSE, nil
    end

    teardown do
      $VERBOSE = @original_verbosity
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
          column_name = 'foobar'
          @adapter.add_column(table_name, column_name, :string, default: 0, null: false)
          if Rails.version.to_f > 4.0
            assert_equal "ADD `#{column_name}` varchar(255) DEFAULT '0' NOT NULL", @adapter.send(:get_commands, table_name).first
          else
            assert_equal "ADD `#{column_name}` varchar(255) DEFAULT 0 NOT NULL", @adapter.send(:get_commands, table_name).first
          end
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
            @column_name = 'foobar'
            @adapter.create_table @table_name, force: true do |t|
              t.string @column_name
            end
          end

          should 'add a CHANGE command to the commands hash' do
            @adapter.change_column(@table_name, @column_name, :string, default: 0, null: false)
            if Rails.version.to_f > 4.0
              assert_equal "CHANGE `#{@column_name}` `#{@column_name}` varchar(255) DEFAULT '0' NOT NULL", @adapter.send(:get_commands, @table_name).first
            else
              assert_equal "CHANGE `#{@column_name}` `#{@column_name}` varchar(255) DEFAULT 0 NOT NULL", @adapter.send(:get_commands, @table_name).first
            end
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
            @column_name = 'foobar'
            @adapter.create_table @table_name, force: true do |t|
              t.string @column_name, default: nil
            end
          end

          should 'add a CHANGE command to the commands hash' do
            new_column_name = 'foobar'
            @adapter.rename_column(@table_name, @column_name, new_column_name)
            assert_equal "CHANGE `#{@column_name}` `#{new_column_name}` varchar(255) DEFAULT NULL", @adapter.send(:get_commands, @table_name).first
          end
        end
      end
    end

    context '#remove_column' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should 'add a DROP COLUMN command to the commands hash' do
          table_name = Faker::Lorem.word
          column_name = 'foobar'
          @adapter.remove_column(table_name, column_name)
          assert_equal "DROP COLUMN `#{column_name}`", @adapter.send(:get_commands, table_name).first
        end

        should 'add multiple DROP COLUMN commands to the commands hash' do
          table_name = Faker::Lorem.word
          column_names = %w(foo bar baz)
          @adapter.remove_column(table_name, *column_names)
          commands = @adapter.send(:get_commands, table_name)
          column_names.each_with_index do |column_name, index|
            assert_equal "DROP COLUMN `#{column_name}`", commands[index]
          end
        end
      end
    end

    context '#add_index' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        context 'with an existing table and columns' do
          setup do
            @table_name = Faker::Lorem.word
            @column_names = %w(foo bar baz)
            @adapter.create_table @table_name, force: true do |t|
              @column_names.each do |column_name|
                t.string(column_name, default: nil)
              end
            end
          end

          should 'add an ADD INDEX command for one column to the commands hash' do
            index_name = Faker::Lorem.words.join('_')
            @adapter.add_index(@table_name, @column_names.first, name: index_name)
            assert_equal "ADD  INDEX `#{index_name}` (`#{@column_names.first}`)", @adapter.send(:get_commands, @table_name).first
          end

          should 'add an ADD UNIQUE INDEX command for one column to the commands hash' do
            index_name = Faker::Lorem.words.join('_')
            @adapter.add_index(@table_name, @column_names.first, unique: true, name: index_name)
            assert_equal "ADD UNIQUE INDEX `#{index_name}` (`#{@column_names.first}`)", @adapter.send(:get_commands, @table_name).first
          end

          should 'add an ADD INDEX command for multiple columns to the commands hash' do
            index_name = Faker::Lorem.words.join('_')
            @adapter.add_index(@table_name, @column_names, name: index_name)
            assert_equal "ADD  INDEX `#{index_name}` (`#{@column_names.join('`, `')}`)", @adapter.send(:get_commands, @table_name).first
          end
        end
      end
    end

    context '#remove_index!' do
      context 'with no existing commands' do
        setup do
          @adapter.instance_variable_set(:@osc_commands, nil)
        end

        should 'add a DROP COLUMN command to the commands hash' do
          table_name = Faker::Lorem.word
          index_name = Faker::Lorem.words.join('_')
          @adapter.remove_index!(table_name, index_name)
          assert_equal "DROP INDEX `#{index_name}`", @adapter.send(:get_commands, table_name).first
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

      context 'with existing commands' do
        setup do
          @commands_hash = 3.times.inject({}) do |hash|
            hash[Faker::Lorem.word] = [Faker::Lorem.sentence]
            hash
          end
          @adapter.instance_variable_set(:@osc_commands, @commands_hash)
        end

        should 'return the entire commands hash when no table is given' do
          assert_equal @commands_hash, @adapter.send(:get_commands)
        end

        should "return only the given table's command array" do
          table = @commands_hash.keys.first
          assert_equal @commands_hash[table], @adapter.send(:get_commands, table)
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
