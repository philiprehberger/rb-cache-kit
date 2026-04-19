# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Internal cache entry with value, TTL, and tags.
    class Entry
      attr_reader :value, :tags, :created_at, :ttl

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

      # Absolute expiration time, or nil if the entry has no TTL.
      #
      # @return [Time, nil]
      def expire_at
        return nil if @ttl.nil?

        @created_at + @ttl
      end

      # Remaining seconds until expiry. Returns nil if no TTL is set,
      # or 0.0 if the entry has already expired.
      #
      # @return [Float, nil]
      def remaining_ttl
        return nil if @ttl.nil?

        remaining = @ttl - (Time.now - @created_at)
        remaining.positive? ? remaining : 0.0
      end

      # Reset the entry's expiration so it now expires at `Time.now + ttl`.
      # A nil ttl clears the expiry (entry becomes non-expiring).
      #
      # @param ttl [Numeric, nil] new time-to-live in seconds
      # @return [void]
      def reset_ttl!(ttl)
        @ttl = ttl
        @created_at = Time.now
      end
    end
  end
end
