module ActiveRecord
  class PtOscMigration < Migration
    # @TODO whitelist all valid pt-osc flags
    DEFAULT_FLAGS = {
      'defaults-file' => nil,
      'recursion-method' => nil,
      'execute' => false,
    }.freeze

    def migrate(direction)
      return unless respond_to?(direction)

      run_mode = percona_config[:run_mode] || 'print'
      raise ArgumentError.new('Invalid run_mode specified in database config') unless run_mode.in? %w(print execute)

      case direction
        when :up   then announce 'migrating'
        when :down then announce 'reverting'
      end

      time   = nil
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        @connection = conn
        if respond_to?(:change)
          if direction == :down
            recorder = CommandRecorder.new(@connection)
            suppress_messages do
              @connection = recorder
              change
            end
            @connection = conn
            time = Benchmark.measure {
              self.revert {
                recorder.inverse.each do |cmd, args|
                  send(cmd, *args)
                end
              }
            }
          else
            time = Benchmark.measure { change }
          end
        else
          time = Benchmark.measure { send(direction) }
        end

        case run_mode
          when 'execute' then time += Benchmark.measure { execute_pt_osc }
          when 'print' then print_pt_osc
        end

        @connection = nil
      end

      case direction
        when :up   then announce 'migrated (%.4fs)' % time.real; write
        when :down then announce 'reverted (%.4fs)' % time.real; write
      end
    end

    protected
    def execute_pt_osc
      return unless @connection.is_a? ActiveRecord::ConnectionAdapters::PtOscAdapter

      @connection.get_commanded_tables.each do |table_name|
        execute_sql = @connection.get_commands_string(table_name)

        Rails.logger.tagged('pt-osc') do |logger|

          database_name = database_config[:database]

          logger.info "Running on #{database_name}|#{table_name}: #{execute_sql}"
          announce 'running pt-online-schema-change'

          [true, false].each do |dry_run|
            command = percona_command(execute_sql, database_name, table_name, execute: !dry_run)
            logger.info "Command is #{command}"
            success = Kernel.system command
            if success
              logger.info "Successfully #{dry_run ? 'dry ran' : 'executed'} on #{database_name}|#{table_name}: #{execute_sql}"
            else
              failure_message = "Unable to #{dry_run ? 'dry run' : 'execute'} query on #{database_name}|#{table_name}: #{execute_sql}"
              logger.error failure_message
              raise RuntimeError.new(failure_message)
            end
          end
        end
      end

      @connection.clear_commands
    end

    def print_pt_osc
      return unless @connection.is_a? ActiveRecord::ConnectionAdapters::PtOscAdapter

      database_name = database_config[:database]

      @connection.get_commanded_tables.each do |table_name|
        execute_sql = @connection.get_commands_string(table_name)

        announce 'Run the following commands:'

        [true, false].each do |dry_run|
          write percona_command(execute_sql, database_name, table_name, execute: !dry_run)
        end

      end

      @connection.clear_commands
    end

    def percona_command(execute_sql, database_name, table_name, options = {})
      command = "pt-online-schema-change --alter '#{execute_sql}' D=#{database_name},t=#{table_name}"

      # Whitelist
      options = HashWithIndifferentAccess.new(options)
      options = options.slice(*DEFAULT_FLAGS.keys)

      # Merge config
      config = percona_config
      if config
        config.slice(*DEFAULT_FLAGS.keys).each do |key, value|
          options[key] ||= value
        end
      end

      # Set defaults
      DEFAULT_FLAGS.each do |key, value|
        options[key] ||= value unless value.nil?
      end

      # Determine run mode
      command += options.delete(:execute) ? ' --execute' : ' --dry-run'

      options.each do |key, value|
        command += " --#{key} #{value}"
      end

      command
    end

    def database_config
      # @TODO better way to config?
      @connection.instance_variable_get(:@config) || ActiveRecord::Base.connection_config
    end

    def percona_config
      database_config[:percona]
    end
  end
end
