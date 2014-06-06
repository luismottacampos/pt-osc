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

        should 'only include flags in DEFAULT_FLAGS' do
          flag = ActiveRecord::PtOscMigration::DEFAULT_FLAGS.first
          begin
            flag = Faker::Lorem.words.join('-')
          end while flag.in? ActiveRecord::PtOscMigration::DEFAULT_FLAGS

          command = @migration.send(:percona_command, '', '', '', flag => nil)
          assert_equal false, command.include?(flag), "Flag #{flag} was given but should not have been."
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
      end
    end
  end
end
