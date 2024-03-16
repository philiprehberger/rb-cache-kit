# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Batch operations for Store.
    module Batch
      # Retrieve multiple keys in a single lock acquisition.
      # Returns only found (non-nil, non-expired) entries, skipping misses.
      #
      # @param keys [Array<String>] cache keys to retrieve
      # @return [Hash] key => value pairs for found entries only
      def get_many(*keys)
        keys = keys.flatten
        @mutex.synchronize do
          result = {}
          keys.each do |key|
            value = fetch_entry(key)
            result[key] = value unless value.nil?
          end
          result
        end
      end
    end
  end
end
