require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.pt_osc_connection(config)
      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config.symbolize_keys)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::PtOscAdapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class PtOscAdapter < Mysql2Adapter
      ADAPTER_NAME = 'pt-osc'

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        add_command(table_name, "RENAME TO #{quote_table_name(new_name)}")
      end

      def add_column(table_name, column_name, type, options = {})
        add_command(table_name, add_column_sql(table_name, column_name, type, options))
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        add_command(table_name, change_column_sql(table_name, column_name, type, options))
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        add_command(table_name, rename_column_sql(table_name, column_name, new_column_name))
      end

      protected
      def add_command(table_name, command)
        @osc_commands ||= {}
        @osc_commands[table_name] ||= []
        @osc_commands[table_name] << command
      end

      def get_commands(table_name)
        @osc_commands ||= {}
        @osc_commands[table_name]
      end

      def get_commands_string(table_name)
        @osc_commands ||= {}
        @osc_commands[table_name] ||= []
        @osc_commands[table_name].join(';')
      end
    end
  end
end
