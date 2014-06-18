require 'test_helper'

class PtOscMigrationUnitTest < Test::Unit::TestCase
  context 'with a pt-osc migration' do
    setup do
      @migration = ActiveRecord::PtOscMigration.new
    end

    context '#percona_command' do
      context 'connected to a pt-osc database' do
        setup do
          ActiveRecord::Base.establish_connection(test_spec)
          @migration.instance_variable_set(:@connection, ActiveRecord::Base.connection)
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
              config.key?(:default) && flag != 'execute'
            end

            command = @migration.send(:percona_command, '', '', '')
            flags_with_defaults.each do |flag, config|
              assert command.include?("--#{flag} #{config[:default]}"),
                     "Default value #{config[:default]} for flag #{flag} was not present in command: #{command}"
            end
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
            @migration.expects(:make_path_absolute).with(@path)
            @migration.send(:percona_command, '', '', '', @options)
          end
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
  end
end
