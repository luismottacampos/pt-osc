require 'active_record/migration'
require 'active_record/connection_adapters/mysql_pt_osc_adapter'

module ActiveRecord
  class PtOscMigration < Migration
    # @TODO whitelist all valid pt-osc flags
    PERCONA_FLAGS = {
      'defaults-file' => {
        mutator: :make_path_absolute,
      },
      'recursion-method' => {
        version: '>= 2.1',
      },
      'execute' => {
        default: false,
      },
    }.freeze

    def self.percona_flags
      PERCONA_FLAGS
    end

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
      return unless @connection.is_a? ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter
      return if @connection.get_commanded_tables.empty?

      database_name = database_config[:database]
      announce 'running pt-online-schema-change'

      @connection.get_commanded_tables.each { |table| migrate_table(database_name, table) }
      @connection.clear_commands
    end

    def migrate_table(database_name, table_name)
      execute_sql = @connection.get_commands_string(table_name)

      logger.info "Running on #{database_name}|#{table_name}: #{execute_sql}"

      [true, false].each { |dry_run| execute_sql_for_table(execute_sql, database_name, table_name, dry_run) }
    end

    def execute_sql_for_table(execute_sql, database_name, table_name, dry_run = true)
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

    def print_pt_osc
      return unless @connection.is_a? ActiveRecord::ConnectionAdapters::MysqlPtOscAdapter

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
      options = options.slice(*self.class.percona_flags.keys)

      # Merge config
      config = percona_config
      if config
        config.slice(*self.class.percona_flags.keys).each do |key, value|
          options[key] ||= value
        end
      end

      # Set defaults
      self.class.percona_flags.each do |flag, flag_config|
        options[flag] = flag_config[:default] if flag_config.key?(:default) && !options.key?(flag)
      end

      "#{command}#{run_mode_flag(options)}#{command_flags(options)}"
    end

    def self.tool_version
      @_tool_version ||= Gem::Version.new(get_tool_version.sub('pt-online-schema-change', '').strip)
    end

    def database_config
      @db_config ||= (@connection.instance_variable_get(:@config) || ActiveRecord::Base.connection_config).with_indifferent_access
    end

    def percona_config
      database_config[:percona] || {}
    end

    def logfile
      File.open(make_path_absolute(percona_config[:log] || 'log/pt_osc.log'), 'a')
    end

    def logger
      return @logger if @logger
      @logger = Logger.new(logfile)
      @logger.formatter = Logger::Formatter.new # Don't let ActiveSupport override with SimpleFormatter
      @logger.progname = 'pt-osc'
      @logger
    end

    private
    def command_flags(options)
      options.map do |key, value|
        flag_options = self.class.percona_flags[key]

        # Satisfy version requirements
        if flag_options.try(:key?, :version)
          next unless Gem::Requirement.new(flag_options[:version]).satisfied_by? self.class.tool_version
        end

        # Mutate the value if needed
        value = send(self.class.percona_flags[key][:mutator], value) if self.class.percona_flags[key].try(:key?, :mutator)

        # Handle boolean flags
        if flag_options.try(:[], :boolean)
          key = "no-#{key}" unless value
          value = nil
        end

        " --#{key} #{value}"
      end.join('')
    end

    def run_mode_flag(options)
      options.delete(:execute) ? ' --execute' : ' --dry-run'
    end

    def self.get_tool_version
      `pt-online-schema-change --version`
    end

    # Flag mutators
    def make_path_absolute(path)
      return path if path[0] == '/'
      # If path is not already absolute, treat it as relative to the app root
      File.expand_path(path, Dir.getwd)
    end
  end
end
