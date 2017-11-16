require 'active_record/migration'
require 'active_record/connection_adapters/mysql_pt_osc_adapter'
require 'shellwords'

module ActiveRecord
  class Migrator
    alias_method :record_version_state_after_migrating_without_reconnect, :record_version_state_after_migrating

    def record_version_state_after_migrating(version)
      ActiveRecord::Base.logger.debug 'Verifying active connections prior to recording version' if ActiveRecord::Base.logger
      # https://github.com/rails/rails/commit/9d1f1b1ea9e5d637984fda4f276db77ffd1dbdcb
      if ActiveRecord::VERSION::MAJOR < 4
        ActiveRecord::Base.verify_active_connections! #Recconect to DB if it's gone away while we were migrating.
      else
        ::ActiveRecord::Base.connection_pool.connections.map(&:verify!)
      end
      record_version_state_after_migrating_without_reconnect(version)
    end
  end

  class UnsupportedMigrationError < ActiveRecordError; end

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
      'check-alter' => {
        boolean: true,
        default: true,
        mutator: :execute_only,
        version: '>= 2.1',
      },
      'user' => {
        mutator: :get_from_config,
        arguments: {
          key_name: 'username',
        },
        default: nil,
      },
      'password' => {
        mutator: :get_from_config,
        default: nil,
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

    def method_missing(method, *arguments, &block) # :nodoc:
      # Putting this here ensures that pt_osc_migration shows up in the caller trace
      super
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
      logger.info "Command is #{self.class.sanitize_command(command)}"

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
          write self.class.sanitize_command(percona_command(execute_sql, database_name, table_name, execute: !dry_run))
        end

      end

      @connection.clear_commands
    end

    def percona_command(execute_sql, database_name, table_name, options = {})
      command = ['pt-online-schema-change', '--alter', execute_sql || '', "D=#{database_name},t=#{table_name}"]

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

      command_parts = command + [run_mode_flag(options)] + command_flags(options)

      command_parts.shelljoin
    end

    def self.tool_version
      @_tool_version ||= Gem::Version.new(get_tool_version.sub('pt-online-schema-change', '').strip)
    end

    def database_config
      @db_config ||= raw_database_config.with_indifferent_access
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
    def raw_database_config
      connection.pool.spec.config || ActiveRecord::Base.connection_config
    end

    def command_flags(options)
      options.flat_map do |key, value|
        next if key == 'execute'
        flag_options = self.class.percona_flags[key]

        # Satisfy version requirements
        if flag_options.try(:key?, :version)
          next unless Gem::Requirement.new(flag_options[:version]).satisfied_by? self.class.tool_version
        end

        # Mutate the value if needed
        if flag_options.try(:key?, :mutator)
          value = send(flag_options[:mutator], value, { all_options: options, flag_name: key }.merge(flag_options[:arguments] || {}))
          next if value.nil? # Allow a mutator to determine the flag shouldn't be used
        end

        # Handle boolean flags
        if flag_options.try(:[], :boolean)
          key = "no-#{key}" unless value
          value = nil
        end

        ["--#{key}", value]
      end.compact
    end

    def run_mode_flag(options)
      options[:execute] ? '--execute' : '--dry-run'
    end

    def self.get_tool_version
      `pt-online-schema-change --version`
    end

    def self.sanitize_command(command)
      command_parts = command.shellsplit
      password_index = command_parts.find_index('--password')
      command_parts[password_index + 1] = '_hidden_' unless password_index.nil? || command_parts.length == password_index + 1
      command_parts.shelljoin
    end

    # Flag mutators
    def make_path_absolute(path, _ = {})
      return path if path[0] == '/'
      # If path is not already absolute, treat it as relative to the app root
      File.expand_path(path, Dir.getwd)
    end

    def execute_only(flag, options = {})
      options[:all_options][:execute] ? flag : self.class.percona_flags[options[:flag_name]][:default]
    end

    def get_from_config(flag, options = {})
      case flag
      when nil
        database_config[options[:key_name] || options[:flag_name]]
      when false
        nil
      else
        flag
      end
    end

    def execute(sql)
      raise ActiveRecord::UnsupportedMigrationError.new("Raw `execute` isn't supported by the pt-osc gem.")
    end
  end
end
