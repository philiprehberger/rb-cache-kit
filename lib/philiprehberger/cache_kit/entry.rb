# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Internal cache entry with value, TTL, and tags.
    class Entry
      attr_reader :value, :tags, :created_at

      # @param value the cached value
      # @param ttl [Numeric, nil] time-to-live in seconds (nil = no expiry)
      # @param tags [Array<String>] tags for bulk invalidation
      def initialize(value, ttl: nil, tags: [])
        @value = value
        @ttl = ttl
        @tags = tags.map(&:to_s)
        @created_at = Time.now
      end

      # Check if the entry has expired.
      #
      # @return [Boolean]
      def expired?
        return false if @ttl.nil?

        (Time.now - @created_at) >= @ttl
      end
    end
  end
end
