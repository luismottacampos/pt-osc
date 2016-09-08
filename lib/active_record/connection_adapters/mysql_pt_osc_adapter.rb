require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.mysql_pt_osc_connection(config)
      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config.symbolize_keys)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::MysqlPtOscAdapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class MysqlPtOscAdapter < Mysql2Adapter
      ADAPTER_NAME = 'mysql-pt-osc'

      def adapter_name
        'mysql2' # For compatibility with code that check adapter name
      end

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

      # Removes the column(s) from the table definition.
      # ===== Examples
      #  remove_column(:suppliers, :qualification)
      #  remove_columns(:suppliers, :qualification, :experience)
      #
      def remove_column(table_name, *column_names)
        if column_names.flatten!
          message = 'Passing array to remove_columns is deprecated, please use ' +
            'multiple arguments, like: `remove_columns(:posts, :foo, :bar)`'
          ActiveSupport::Deprecation.warn message, caller
        end

        column_names.map do |column_name|
          add_command(table_name, "DROP COLUMN #{quote_column_name(column_name)}")
        end
      end

      # Adds a new index to the table. +column_name+ can be a single Symbol, or
      # an Array of Symbols.
      #
      # The index will be named after the table and the column name(s), unless
      # you pass <tt>:name</tt> as an option.
      #
      # ===== Examples
      #
      # ====== Creating a simple index
      #  add_index(:suppliers, :name)
      # generates
      #  CREATE INDEX suppliers_name_index ON suppliers(name)
      #
      # ====== Creating a unique index
      #  add_index(:accounts, [:branch_id, :party_id], :unique => true)
      # generates
      #  CREATE UNIQUE INDEX accounts_branch_id_party_id_index ON accounts(branch_id, party_id)
      #
      # ====== Creating a named index
      #  add_index(:accounts, [:branch_id, :party_id], :unique => true, :name => 'by_branch_party')
      # generates
      #  CREATE UNIQUE INDEX by_branch_party ON accounts(branch_id, party_id)
      #
      # ====== Creating an index with specific key length
      #  add_index(:accounts, :name, :name => 'by_name', :length => 10)
      # generates
      #  CREATE INDEX by_name ON accounts(name(10))
      #
      #  add_index(:accounts, [:name, :surname], :name => 'by_name_surname', :length => {:name => 10, :surname => 15})
      # generates
      #  CREATE INDEX by_name_surname ON accounts(name(10), surname(15))
      #
      # ====== Creating an index with a sort order (desc or asc, asc is the default)
      #  add_index(:accounts, [:branch_id, :party_id, :surname], :order => {:branch_id => :desc, :part_id => :asc})
      # generates
      #  CREATE INDEX by_branch_desc_party ON accounts(branch_id DESC, party_id ASC, surname)
      #
      # Note: mysql doesn't yet support index order (it accepts the syntax but ignores it)
      #
      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns = add_index_options(table_name, column_name, options)
        add_command(table_name, "ADD #{index_type} INDEX #{quote_column_name(index_name)} (#{index_columns})")
      end

      def remove_index!(table_name, index_name) #:nodoc:
        add_command(table_name, "DROP INDEX #{quote_column_name(index_name)}")
      end

      def clear_commands
        @osc_commands = {}
      end

      def get_commands_string(table_name)
        get_commands[table_name] ||= []
        get_commands[table_name].join(',')
      end

      def get_commanded_tables
        get_commands.keys
      end

      protected
      def add_command(table_name, command)
        warn (<<-WARN
        You are trying to ALTER table "#{table_name}" with the mysql_pt_osc adapter without using an PtOscMigration.
        Be aware that ALTER commands will only be executed via pt-online-schema-change inside of an ActiveRecord::PtOscMigration.
        It is likely that although your migration will complete, no schema alterations have been made.
        WARN
        ) if caller.any? { |c| c.include? 'active_record/migration.rb' } && caller.none? { |c| c.include? 'active_record/pt_osc_migration.rb' }
        get_commands[table_name] ||= []
        get_commands[table_name] << command
      end

      # Provides the opportunity to handle warnings in a custom way
      # @param [String] message
      def warn(message)
        # Rake tasks loaded through Railties had warnings silenced before Rails 4.1
        # @see https://github.com/rails/rails/pull/11601
        defined?(Rails) && Rails.version < '4.1' ? enable_warnings { super } : super
      end

      def get_commands(table_name = nil)
        @osc_commands ||= {}
        table_name.nil? ? @osc_commands : @osc_commands[table_name]
      end
    end
  end
end
