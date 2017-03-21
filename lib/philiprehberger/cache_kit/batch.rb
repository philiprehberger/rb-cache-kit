# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Batch operations for Store.
    module Batch
      # Retrieve multiple keys in a single lock acquisition.
      #
      # @param keys [Array<String>] cache keys to retrieve
      # @return [Hash] key => value pairs (missing/expired keys map to nil)
      def get_many(keys)
        @mutex.synchronize do
          keys.each_with_object({}) do |key, result|
            result[key] = fetch_entry(key)
          end
        end
      end
    end
  end
end
