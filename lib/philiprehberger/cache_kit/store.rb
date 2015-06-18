# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Thread-safe in-memory LRU cache with TTL and tag-based invalidation.
    class Store
      # @param max_size [Integer] maximum number of entries (LRU eviction when exceeded)
      def initialize(max_size: 1000)
        @max_size = max_size
        @data = {}
        @order = []
        @mutex = Mutex.new
        @hits = 0
        @misses = 0
        @evictions = 0
      end

      # Get a value by key. Returns nil if missing or expired.
      #
      # @param key [String] the cache key
      # @return the cached value, or nil
      def get(key)
        @mutex.synchronize do
          entry = @data[key]
          unless entry
            @misses += 1
            return nil
          end

          if entry.expired?
            remove_entry(key)
            @misses += 1
            return nil
          end

          @hits += 1
          touch(key)
          entry.value
        end
      end

      # Store a value.
      #
      # @param key [String] the cache key
      # @param value the value to cache
      # @param ttl [Numeric, nil] time-to-live in seconds
      # @param tags [Array<String>] tags for bulk invalidation
      # @return the stored value
      def set(key, value, ttl: nil, tags: [])
        @mutex.synchronize do
          remove_entry(key) if @data.key?(key)
          evict if @data.size >= @max_size

          @data[key] = Entry.new(value, ttl: ttl, tags: tags)
          @order.push(key)
          value
        end
      end

      # Get or compute a value.
      #
      # @param key [String] the cache key
      # @param ttl [Numeric, nil] TTL for newly computed values
      # @param tags [Array<String>] tags for newly computed values
      # @yield computes the value if not cached
      # @return the cached or computed value
      def fetch(key, ttl: nil, tags: [], &block)
        value = get(key)
        return value unless value.nil?

        computed = block.call
        set(key, computed, ttl: ttl, tags: tags)
        computed
      end

      # Delete a specific key.
      #
      # @param key [String] the cache key
      # @return [Boolean] true if the key existed
      def delete(key)
        @mutex.synchronize do
          removed = @data.key?(key)
          remove_entry(key)
          removed
        end
      end

      # Invalidate all entries with a given tag.
      #
      # @param tag [String] the tag to invalidate
      # @return [Integer] number of entries removed
      def invalidate_tag(tag)
        @mutex.synchronize do
          tag_s = tag.to_s
          keys = @data.select { |_, entry| entry.tags.include?(tag_s) }.keys
          keys.each { |k| remove_entry(k) }
          keys.size
        end
      end

      # Clear all entries.
      #
      # @return [void]
      def clear
        @mutex.synchronize do
          @data.clear
          @order.clear
        end
      end

      # @return [Integer] number of entries (including expired ones not yet evicted)
      def size
        @mutex.synchronize { @data.size }
      end

      # @param key [String]
      # @return [Boolean] true if the key exists and is not expired
      def key?(key)
        @mutex.synchronize do
          entry = @data[key]
          return false unless entry
          return false if entry.expired?

          true
        end
      end

      # Returns all non-expired keys.
      #
      # @return [Array<String>] list of valid keys
      def keys
        @mutex.synchronize do
          @data.each_with_object([]) do |(key, entry), result|
            result << key unless entry.expired?
          end
        end
      end

      # Hash-like read access. Alias for #get.
      #
      # @param key [String] the cache key
      # @return the cached value, or nil
      def [](key)
        get(key)
      end

      # Hash-like write access. Alias for #set without TTL/tags.
      #
      # @param key [String] the cache key
      # @param value the value to cache
      # @return the stored value
      def []=(key, value)
        set(key, value)
      end

      # Returns cache statistics.
      #
      # @return [Hash] stats with :size, :hits, :misses, :evictions
      def stats
        @mutex.synchronize do
          { size: @data.size, hits: @hits, misses: @misses, evictions: @evictions }
        end
      end

      # Removes all expired entries.
      #
      # @return [Integer] number of entries removed
      def prune
        @mutex.synchronize do
          expired_keys = @data.select { |_, entry| entry.expired? }.keys
          expired_keys.each { |k| remove_entry(k) }
          expired_keys.size
        end
      end

      private

      def touch(key)
        @order.delete(key)
        @order.push(key)
      end

      def evict
        oldest = @order.first
        if oldest
          remove_entry(oldest)
          @evictions += 1
        end
      end

      def remove_entry(key)
        @data.delete(key)
        @order.delete(key)
      end
    end
  end
end
