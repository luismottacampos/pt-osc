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
    end
  end
end
