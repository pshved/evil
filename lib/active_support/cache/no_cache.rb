# NoCache to disable caching
module ActiveSupport
  module Cache
    class NoCache < Store
      def read_entry(name, options)
        return nil
      end
      def write_entry(name, value, options)
      end
      def delete_entry(name, options)
      end
    end
  end
end
