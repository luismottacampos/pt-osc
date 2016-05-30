require 'test_helper'

class PtOscMigrationFunctionalTest < ActiveRecord::TestCase
  class TestMigration < ActiveRecord::PtOscMigration; end

  context 'a migration' do
    setup do
      @migration = TestMigration.new
      ActiveRecord::PtOscMigration.stubs(:tool_version).returns(Gem::Version.new('100'))
    end

    teardown do
      ActiveRecord::PtOscMigration.unstub(:tool_version)
    end

    context 'connected to a pt-osc database' do
      setup do
        ActiveRecord::Base.establish_connection(test_spec)
        @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
      end

      context 'on an existing table with an existing column' do
        setup do
          @table_name = Faker::Lorem.word
          @column_name = 'foobar'
          @index_name = Faker::Lorem.words.join('_')

          ActiveRecord::Base.connection.execute "DROP TABLE IF EXISTS `#{@table_name}`;"
          ActiveRecord::Base.connection.execute <<-SQL
          CREATE TABLE `#{@table_name}` (
            `#{@column_name}` varchar(255) DEFAULT NULL,
            KEY `#{@index_name}` (`#{@column_name}`)
          );
          SQL
        end

        teardown do
          ActiveRecord::Base.connection.execute "DROP TABLE IF EXISTS `#{@table_name}`;"
        end

        context 'a raw SQL execute migration' do
          setup do
            TestMigration.class_eval <<-EVAL
            def up
              execute 'SELECT 1'
            end
            EVAL
            @migration.expects(:print_pt_osc).never
            @migration.expects(:execute_pt_osc).never
            @migration.connection.expects(:execute).never
          end

          teardown do
            @migration.unstub(:print_pt_osc)
            @migration.unstub(:execute_pt_osc)
            @migration.connection.unstub(:execute)
          end

          should 'throw an exception' do
            assert_raise ActiveRecord::UnsupportedMigrationError do
              @migration.migrate(:up)
            end
          end
        end

        context 'a migration with only ALTER statements' do
          setup do
            @renamed_column_name = 'foobar'
            @new_column_name = 'bazqux'
            @new_table_name = Faker::Lorem.word
            @index_name_2 = "#{@index_name}_2"
            @index_name_3 = "#{@index_name}_3"

            TestMigration.class_eval <<-EVAL
            def change
              rename_table  :#{@table_name}, :#{@new_table_name}
              add_column    :#{@table_name}, :#{@new_column_name}, :integer
              change_column :#{@table_name}, :#{@column_name}, :varchar, default: 'newthing'
              change_column :#{@table_name}, :#{@column_name}, :varchar, default: :newsymbol
              rename_column :#{@table_name}, :#{@column_name}, :#{@renamed_column_name}
              remove_column :#{@table_name}, :#{@column_name}
              add_index     :#{@table_name}, :#{@column_name}, name: :#{@index_name_2}
              add_index     :#{@table_name}, [:#{@new_column_name}, :#{@renamed_column_name}], name: :#{@index_name_3}, unique: true
              remove_index  :#{@table_name}, name: :#{@index_name}
            end
            EVAL
          end

          teardown do
            TestMigration.send(:remove_method, :change)
          end

          context 'with suppressed output' do
            setup do
              @migration.stubs(:write)
              @migration.stubs(:announce)
            end

            teardown do
              @migration.unstub(:write, :announce)
            end

            context 'ignoring schema lookups' do
              setup do
                # Kind of a hacky way to do this
                ignored_sql = ActiveRecord::SQLCounter.ignored_sql + [
                  /^SHOW FULL FIELDS FROM/,
                  /^SHOW COLUMNS FROM/,
                  /^SHOW KEYS FROM/,
                ]
                ActiveRecord::SQLCounter.any_instance.stubs(:ignore).returns(ignored_sql)
              end

              teardown do
                ActiveRecord::SQLCounter.any_instance.unstub(:ignore)
              end

              should 'not execute any queries immediately' do
                assert_no_queries { @migration.change }
              end

              context 'with a working pt-online-schema-change' do
                setup do
                  Kernel.expects(:system).with(regexp_matches(/^pt-online-schema-change/)).twice.returns(true)
                end

                teardown do
                  Kernel.unstub(:system)
                end

                should 'not directly execute any queries when migrating' do
                  assert_no_queries { @migration.migrate(:up) }
                end
              end
            end

            context 'the resulting command' do
              should 'have the correct pt-osc ALTER statement' do
                expected_alter = <<-ALTER
                  RENAME TO `#{@new_table_name}`
                  ADD `#{@new_column_name}` int(11)
                  CHANGE `#{@column_name}` `#{@column_name}` varchar DEFAULT 'newthing'
                  CHANGE `#{@column_name}` `#{@column_name}` varchar DEFAULT 'newsymbol'
                  CHANGE `#{@column_name}` `#{@renamed_column_name}` varchar(255) DEFAULT NULL
                  DROP COLUMN `#{@column_name}`
                  ADD  INDEX `#{@index_name_2}` (`#{@column_name}`)
                  ADD UNIQUE INDEX `#{@index_name_3}` (`#{@new_column_name}`, `#{@renamed_column_name}`)
                  DROP INDEX `#{@index_name}`
                ALTER
                expected_alter.strip!.gsub!(/^\s*/, '').gsub!("\n", ',')

                @migration.change
                assert_equal expected_alter, @migration.connection.get_commands_string(@table_name)
              end
            end
          end
        end
      end
    end

    context 'connected without checking alter statements' do
      setup do
        @old_connection = @migration.instance_variable_get(:@connection)
        ActiveRecord::Base.establish_connection(test_spec('test_no_check_alter'))
        @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
      end

      should 'check ALTER when dry-running sql' do
        command = @migration.send(:percona_command, nil, nil, nil, execute: false)
        assert command.include?('--check-alter'), "Command '#{command}' did not include ALTER check."
        assert_equal false, command.include?('--no-check-alter'), "Command '#{command}' should not disable ALTER check."
      end

      should 'not check ALTER when executing sql' do
        command = @migration.send(:percona_command, nil, nil, nil, execute: true)
        assert command.include?('--no-check-alter'), "Command '#{command}' should not include ALTER check."
        assert_equal false, command.include?('--check-alter'), "Command '#{command}' should disable ALTER check."
      end
    end
  end
end

class PtOscMigrationMigratorFunctionalTest < ActiveRecord::TestCase
  class TestMigrator < ActiveRecord::Migrator; end

  context 'updating version post migration' do
    setup do
      @migrator = TestMigrator.new(nil, nil)
    end

    should 'verify connections before recording version' do
      ActiveRecord::Base.connection.raw_connection.close
      @migrator.send(:record_version_state_after_migrating, 0)
    end
  end
end
