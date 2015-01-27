require 'test_helper'

class PtOscMigrationUnitTest < Test::Unit::TestCase
  context 'with a pt-osc migration' do
    setup do
      @migration = ActiveRecord::PtOscMigration.new
      @tool_version = states('tool_version').starts_as('100')
      ActiveRecord::PtOscMigration.stubs(:tool_version).returns(Gem::Version.new('100')).when(@tool_version.is('100'))
      @migration.stubs(:write)
      @migration.stubs(:announce)
    end

    teardown do
      ActiveRecord::PtOscMigration.unstub(:tool_version)
      @migration.unstub(:write, :announce)
    end

    context '#percona_command' do
      context 'connected to a pt-osc database' do
        setup do
          @old_connection = @migration.instance_variable_get(:@connection)
          ActiveRecord::Base.establish_connection(test_spec)
          @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        should 'only include flags in PERCONA_FLAGS' do
          flag = ActiveRecord::PtOscMigration.percona_flags.first
          begin
            flag = Faker::Lorem.words.join('-')
          end while flag.in? ActiveRecord::PtOscMigration.percona_flags

          command = @migration.send(:percona_command, '', '', '', flag => nil)
          assert_equal false, command.include?(flag), "Flag #{flag} was given but should not have been."
        end

        context 'with flags having defaults' do
          setup do
            # add some dummy flags
            dummy_flags = 3.times.inject({}) do |hash|
              dummy_flag = Faker::Lorem.words.join('-')
              hash[dummy_flag] = { default: Faker::Lorem.word }
              hash
            end

            standard_flags = ActiveRecord::PtOscMigration.percona_flags
            ActiveRecord::PtOscMigration.stubs(:percona_flags).returns(standard_flags.merge(dummy_flags))
          end

          teardown do
            ActiveRecord::PtOscMigration.unstub(:percona_flags)
          end

          should 'set missing flags to default values' do
            flags_with_defaults = ActiveRecord::PtOscMigration.percona_flags.select do |flag, config|
              config.key?(:default) && flag != 'execute' && !config[:boolean]
            end

            command = @migration.send(:percona_command, '', '', '')
            flags_with_defaults.each do |flag, config|
              assert command.include?("--#{flag} #{config[:default]}"),
                     "Default value #{config[:default]} for flag #{flag} was not present in command: #{command}"
            end
          end
        end

        context 'with flags having version requirements' do
          setup do
            flags = ActiveRecord::PtOscMigration.percona_flags.merge({ 'flag-with-requirement' => { version: '> 2.0' } })
            ActiveRecord::PtOscMigration.stubs(:percona_flags).returns(flags)
          end

          teardown do
            ActiveRecord::PtOscMigration.unstub(:percona_flags)
          end

          context 'with matching tool version' do
            setup do
              @old_tool_version = @tool_version.current_state
              ActiveRecord::PtOscMigration.stubs(:tool_version).returns(Gem::Version.new('2.6.40')).when(@tool_version.is('2.6.40'))
              @tool_version.become('2.6.40')
            end

            teardown do
              @tool_version.become(@old_tool_version)
            end

            should 'contain the flag in the output' do
              command = @migration.send(:percona_command, '', '', '', 'flag-with-requirement' => 'foobar')
              assert command.include?('--flag-with-requirement foobar'),
                     "Flag was not included in command '#{command}' despite meeting version requirement."
            end
          end

          context 'with non-matching tool version' do
            setup do
              @old_tool_version = @tool_version.current_state
              ActiveRecord::PtOscMigration.stubs(:tool_version).returns(Gem::Version.new('1.12')).when(@tool_version.is('1.12'))
              @tool_version.become('1.12')
            end

            teardown do
              @tool_version.become(@old_tool_version)
            end

            should 'not contain the flag in the output' do
              command = @migration.send(:percona_command, '', '', '', 'flag-with-requirement' => 'foobar')
              assert_equal false, command.include?('--flag-with-requirement'),
                           "Flag was included in command '#{command}' despite not meeting version requirement."
            end
          end
        end

        context 'with boolean flags' do
          setup do
            flags = ActiveRecord::PtOscMigration.percona_flags.merge({ 'boolean-flag' => { boolean: true } })
            ActiveRecord::PtOscMigration.stubs(:percona_flags).returns(flags)
          end

          teardown do
            ActiveRecord::PtOscMigration.unstub(:percona_flags)
          end

          should 'include just the flag (no value) when true' do
            command = @migration.send(:percona_command, '', '', '', 'boolean-flag' => true)
            matches_eof = command =~ /\-\-boolean\-flag\s*$/
            matches_middle = command =~ /\-\-boolean\-flag\s*\-\-/
            assert matches_eof || matches_middle, "Boolean flag was malformed in command '#{command}'."
          end

          should 'include a "no" version of the flag when false' do
            command = @migration.send(:percona_command, '', '', '', 'boolean-flag' => false)
            matches_eof = command =~ /\-\-no\-boolean\-flag\s*$/
            matches_middle = command =~ /\-\-no\-boolean\-flag\s*\-\-/
            assert matches_eof || matches_middle, "Boolean flag was malformed in command '#{command}'."
          end
        end

        should 'perform a dry run if execute not specified' do
          command = @migration.send(:percona_command, '', '', '')
          assert command.include?('--dry-run')
        end

        should 'perform only execute if specified' do
          command = @migration.send(:percona_command, '', '', '', execute: true)
          assert_equal false, command.include?('--dry-run')
          assert command.include?('--execute')
        end

        context 'given a defaults-file' do
          setup do
            @path = Faker::Lorem.words.join('/')
            @options = { :'defaults-file' => @path }
          end

          should 'call #make_path_absolute' do
            @migration.expects(:make_path_absolute).with(@path, anything)
            @migration.send(:percona_command, '', '', '', @options)
          end
        end
      end

      context 'connected to a pt-osc database in print mode' do
        setup do
          @old_connection = @migration.instance_variable_get(:@connection)
          ActiveRecord::Base.establish_connection(test_spec('test_print'))
          @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        should 'have print as the run_mode' do
          assert_equal 'print', @migration.send(:percona_config)[:run_mode]
        end

        should 'call print_pt_osc' do
          @migration.expects(:print_pt_osc).once.returns(nil)
          @migration.expects(:execute_pt_osc).never
          @migration.migrate(:up)
        end
      end

      context 'connected to a pt-osc database in print mode as string' do
        setup do
          @old_connection = @migration.instance_variable_get(:@connection)
          ActiveRecord::Base.establish_connection(test_spec('test_print_string'))
          @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        should 'have print as the run_mode' do
          assert_equal 'print', @migration.send(:percona_config)[:run_mode]
        end

        should 'call print_pt_osc' do
          @migration.expects(:print_pt_osc).once.returns(nil)
          @migration.expects(:execute_pt_osc).never
          @migration.migrate(:up)
        end
      end

      context 'connected to a pt-osc database in execute mode' do
        setup do
          @old_connection = @migration.instance_variable_get(:@connection)
          ActiveRecord::Base.establish_connection(test_spec('test_execute'))
          @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        should 'have execute as the run_mode' do
          assert_equal 'execute', @migration.send(:percona_config)[:run_mode]
        end

        should 'call execute_pt_osc' do
          @migration.expects(:execute_pt_osc).once.returns(nil)
          @migration.expects(:print_pt_osc).never
          @migration.migrate(:up)
        end
      end

      context 'connected to a pt-osc database in execute mode as string' do
        setup do
          @old_connection = @migration.instance_variable_get(:@connection)
          ActiveRecord::Base.establish_connection(test_spec('test_execute_string'))
          @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        should 'have execute as the run_mode' do
          assert_equal 'execute', @migration.send(:percona_config)[:run_mode]
        end

        should 'call execute_pt_osc' do
          @migration.expects(:execute_pt_osc).once.returns(nil)
          @migration.expects(:print_pt_osc).never
          @migration.migrate(:up)
        end
      end
    end

    context '#make_path_absolute' do
      context 'with an absolute path' do
        setup do
          @path = "/#{Faker::Lorem.words.join('/')}"
        end

        should 'return the path unmodified' do
          assert_equal @path, @migration.send(:make_path_absolute, @path)
        end
      end

      context 'with a relative path' do
        setup do
          @path = Faker::Lorem.words.join('/')
        end

        should 'return an absolute path' do
          assert_equal '/', @migration.send(:make_path_absolute, @path)[0]
        end
      end
    end

    context '#execute_only' do
      should 'return the default flag value during a dry run' do
        ActiveRecord::PtOscMigration.stubs(:percona_flags).returns('foo' => { default: 'bar' })
        assert_equal 'bar', @migration.send(:execute_only, 'baz', all_options: { execute: false }, flag_name: 'foo')
        ActiveRecord::PtOscMigration.unstub(:percona_flags)
      end

      should 'return nil during a dry run if there is no default value' do
        ActiveRecord::PtOscMigration.stubs(:percona_flags).returns('foo' => {})
        assert_nil @migration.send(:execute_only, 'baz', all_options: { execute: false }, flag_name: 'foo')
        ActiveRecord::PtOscMigration.unstub(:percona_flags)
      end

      should 'pass the flag through when executing' do
        assert_equal 'baz', @migration.send(:execute_only, 'baz', all_options: { execute: true }, flag_name: 'foo')
      end
    end

    context '#execute_pt_osc' do
      context 'with a pt-osc connection' do
        setup do
          @mock_connection = mock
          @mock_connection.stubs(:is_a?).with(ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter).returns(true)

          @old_connection = @migration.instance_variable_get(:@connection)
          @migration.instance_variable_set(:@connection, @mock_connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        context 'connected to a database' do
          setup do
            @database_name = Faker::Lorem.word
            @migration.stubs(:database_config).returns(database: @database_name)
          end

          teardown do
            @migration.unstub(:database_config)
          end

          context 'with no tables or commands' do
            setup do
              fake_not_empty_array = []
              fake_not_empty_array.stubs(:empty?).returns(false)
              @mock_connection.stubs(:get_commanded_tables).returns(fake_not_empty_array)
              @mock_connection.stubs(:clear_commands)
            end

            teardown do
              @mock_connection.unstub(:get_commanded_tables)
              @mock_connection.unstub(:clear_commands)
            end

            should 'announce its intention' do
              @migration.expects(:announce).with('running pt-online-schema-change')
              @migration.send(:execute_pt_osc)
            end

            should 'call migrate_table for each table' do
              num_tables = (0..5).to_a.sample
              @mock_connection.unstub(:get_commanded_tables)
              @mock_connection.expects(:get_commanded_tables).twice.returns(num_tables.times.map { Faker::Lorem.word })

              @migration.expects(:migrate_table).times(num_tables)
              quietly { @migration.send(:execute_pt_osc) }
            end

            should 'clear commands when finished' do
              @mock_connection.expects(:clear_commands)
              quietly { @migration.send(:execute_pt_osc) }
            end
          end
        end
      end
    end

    context '#migrate_table' do
      context 'with a pt-osc connection' do
        setup do
          @mock_connection = mock

          @old_connection = @migration.instance_variable_get(:@connection)
          @migration.instance_variable_set(:@connection, @mock_connection)
        end

        teardown do
          @migration.instance_variable_set(:@connection, @old_connection)
        end

        context 'with a command string' do
          setup do
            @mock_connection.stubs(:get_commands_string).returns('<<command string>>')
          end

          teardown do
            @mock_connection.unstub(:get_commands_string)
          end

          context 'with stubbed log' do
            setup do
              @dummy_log = StringIO.new
              @migration.stubs(:logfile).returns(@dummy_log)
            end

            teardown do
              @migration.unstub(:logfile)
            end

            should 'log the database, table, and SQL command' do
              database_name = Faker::Lorem.word
              table_name = Faker::Lorem.word

              @migration.stubs(:execute_sql_for_table)
              @migration.send(:migrate_table, database_name, table_name)

              assert database_name.in?(@dummy_log.string), 'Log entry did not contain database name'
              assert table_name.in?(@dummy_log.string),  'Log entry did not contain table name'
              assert '<<command string>>'.in?(@dummy_log.string),  'Log entry did not contain command string'
            end

            should 'call execute twice (dry run and execute)' do
              @migration.expects(:execute_sql_for_table).with(anything, anything, anything, true).once
              @migration.expects(:execute_sql_for_table).with(anything, anything, anything, false).once
              @migration.send(:migrate_table, nil, nil)
            end
          end
        end
      end
    end

    context '#execute_sql_for_table' do
      context 'with stubbed command' do
        setup do
          Kernel.stubs(:system).returns(true)
        end

        teardown do
          Kernel.unstub(:system)
        end

        context 'with stubbed log' do
          setup do
            @dummy_log = StringIO.new
            @migration.stubs(:logfile).returns(@dummy_log)
          end

          teardown do
            @migration.unstub(:logfile)
          end

          should 'log the command' do
            @migration.expects(:percona_command).returns('<<percona command>>')
            @migration.send(:execute_sql_for_table, nil, nil, nil)
            assert '<<percona command>>'.in?(@dummy_log.string), 'Log entry did not contain percona command'
          end

          context 'with successful execution' do
            setup do
              Kernel.expects(:system).returns(true)
            end

            teardown do
              Kernel.unstub(:system)
            end

            should 'log success' do
              @migration.send(:execute_sql_for_table, nil, nil, nil)
              assert 'Success'.in?(@dummy_log.string), 'Success not mentioned in log'
            end
          end

          context 'with failed execution' do
            setup do
              Kernel.expects(:system).returns(false)
            end

            teardown do
              Kernel.unstub(:system)
            end

            should 'log failure' do
              @migration.send(:execute_sql_for_table, nil, nil, nil) rescue nil
              assert 'Unable to'.in?(@dummy_log.string), 'Failure not mentioned in log'
            end

            should 'raise a RuntimeError' do
              assert_raises(RuntimeError) { @migration.send(:execute_sql_for_table, nil, nil, nil) }
            end
          end
        end
      end
    end

    context '#logger' do
      context 'with stubbed log' do
        setup do
          @dummy_log = StringIO.new
          @migration.stubs(:logfile).returns(@dummy_log)
        end

        teardown do
          @migration.unstub(:logfile)
        end

        should 'log entries with "pt-osc"' do
          logger = @migration.send(:logger)
          logger.info 'test'
          assert 'pt-osc'.in?(@dummy_log.string), "Log entry did not contain 'pt-osc': #{@dummy_log.string}"
        end
      end
    end

    context '#logfile' do
      context 'with nothing in config' do
        setup do
          @migration.stubs(:percona_config).returns({})
        end

        teardown do
          @migration.unstub(:percona_config)
        end

        should 'use log/pt_osc.log' do
          @migration.stubs(:make_path_absolute).with('log/pt_osc.log')
                    .returns(File.expand_path('../dummy/log/pt_osc.log', File.dirname(__FILE__)))
          logfile = @migration.send(:logfile)
          assert 'log/pt_osc.log'.in?(logfile.path), 'Default log file not found in path'
        end
      end

      context 'with a logfile specified in config' do
        setup do
          @migration.stubs(:percona_config).returns(log: 'log/fakelog.file')
        end

        teardown do
          @migration.unstub(:percona_config)
        end

        should 'use log/pt_osc.log' do
          @migration.stubs(:make_path_absolute).with('log/fakelog.file')
                    .returns(File.expand_path('../dummy/log/fakelog.file', File.dirname(__FILE__)))
          logfile = @migration.send(:logfile)
          assert 'log/fakelog.file'.in?(logfile.path), 'Configured log file not found in path'
        end
      end
    end
  end

  context '#tool_version' do
    context 'with known tool version' do
      setup do
        ActiveRecord::PtOscMigration.stubs(:get_tool_version).returns('pt-online-schema-change 2.2.7')
      end

      teardown do
        ActiveRecord::PtOscMigration.unstub(:get_tool_version)
      end

      should 'return a Gem::Version with the expected value' do
        assert_instance_of Gem::Version, ActiveRecord::PtOscMigration.send(:tool_version)
        assert_equal '2.2.7', ActiveRecord::PtOscMigration.send(:tool_version).version
      end
    end
  end
end
