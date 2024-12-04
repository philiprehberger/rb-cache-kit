# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Thread-safe in-memory LRU cache with TTL and tag-based invalidation.
    class Store
      include Callbacks
      include TagStats
      include Batch
      include Serializable
      include Eviction

      # @param max_size [Integer] maximum number of entries (LRU eviction when exceeded)
      def initialize(max_size: 1000)
        @max_size = max_size
        @data = {}
        @order = []
        @mutex = Mutex.new
        @hits = 0
        @misses = 0
        @evictions = 0
        init_callbacks
        init_tag_stats
      end

      # Get a value by key. Returns nil if missing or expired.
      def get(key)
        @mutex.synchronize { fetch_entry(key) }
      end

      # Store a value with optional TTL and tags.
      def set(key, value, ttl: nil, tags: [])
        @mutex.synchronize { store_entry(key, value, ttl: ttl, tags: tags) }
      end

      # Get or compute a value (thread-safe).
      def fetch(key, ttl: nil, tags: [], &block)
        @mutex.synchronize { fetch_or_compute(key, ttl: ttl, tags: tags, &block) }
      end

      # @return [Boolean] true if the key existed
      def delete(key)
        @mutex.synchronize { delete_entry(key) }
      end

      # Invalidate all entries with a given tag.
      def invalidate_tag(tag)
        @mutex.synchronize { invalidate_by_tag(tag) }
      end

      def clear
        @mutex.synchronize { @data.clear && @order.clear }
      end

      def size
        @mutex.synchronize { @data.size }
      end

      def key?(key)
        @mutex.synchronize { key_present?(key) }
      end

      def keys
        @mutex.synchronize { @data.reject { |_, e| e.expired? }.keys }
      end

      def [](key) = get(key)

      def []=(key, value)
        set(key, value)
      end

      # @return [Hash] cache statistics, optionally filtered by tag
      def stats(tag: nil)
        @mutex.synchronize { tag ? tag_stats_for(tag) : global_stats }
      end

      def prune
        @mutex.synchronize { prune_expired }
      end

      # Bulk set multiple entries in a single lock acquisition
      #
      # @param hash [Hash] key => value pairs
      # @param ttl [Integer, nil] time-to-live in seconds
      # @param tags [Array<String>] tags for all entries
      # @return [void]
      def set_many(hash, ttl: nil, tags: [])
        @mutex.synchronize do
          hash.each { |key, value| store_entry(key, value, ttl: ttl, tags: tags) }
        end
      end

      # Prune expired entries and return the count of evicted items
      #
      # @return [Integer] number of evicted entries
      def compact
        @mutex.synchronize do
          expired_keys = @data.select { |_, entry| entry.expired? }.keys
          expired_keys.each { |key| remove_entry(key) }
          expired_keys.length
        end
      end

      # Reset the TTL of an existing entry without changing its value
      #
      # @param key [String] the cache key
      # @param ttl [Integer, nil] new TTL in seconds
      # @return [Boolean] true if the key exists and was refreshed
      def refresh(key, ttl: nil)
        @mutex.synchronize do
          entry = @data[key]
          return false if entry.nil? || entry.expired?

          remove_entry(key)
          @data[key] = Entry.new(entry.value, ttl: ttl, tags: entry.tags)
          @order.push(key)
          true
        end
      end

      # Remaining seconds until the entry expires.
      #
      # Returns nil when the key is missing, expired, or has no TTL.
      #
      # @param key [String] the cache key
      # @return [Float, nil]
      def ttl(key)
        @mutex.synchronize do
          entry = @data[key]
          next nil if entry.nil? || entry.expired?

          entry.remaining_ttl
        end
      end

      # Absolute expiration time of the entry.
      #
      # Returns nil when the key is missing, expired, or has no TTL.
      #
      # @param key [String] the cache key
      # @return [Time, nil]
      def expire_at(key)
        @mutex.synchronize do
          entry = @data[key]
          next nil if entry.nil? || entry.expired?

          entry.expire_at
        end
      end

      # Bulk-delete multiple keys in a single lock acquisition.
      # Does not fire eviction callbacks (matches #delete semantics).
      #
      # @param keys [Array<String>] keys to delete
      # @return [Integer] number of keys that were actually removed
      def delete_many(*keys)
        keys = keys.flatten
        @mutex.synchronize do
          removed = 0
          keys.each do |key|
            next unless @data.key?(key)

            remove_entry(key)
            removed += 1
          end
          removed
        end
      end

      # Return the keys associated with a given tag.
      # Excludes expired entries.
      #
      # @param tag [String, Symbol]
      # @return [Array<String>]
      def keys_by_tag(tag)
        tag_s = tag.to_s
        @mutex.synchronize do
          @data.each_with_object([]) do |(key, entry), acc|
            next if entry.expired?

            acc << key if entry.tags.include?(tag_s)
          end
        end
      end

      # Atomically increment a numeric entry. Initializes missing or
      # expired keys to 0 before applying the delta.
      #
      # @param key [String] the cache key
      # @param by [Numeric] amount to add (default 1)
      # @param ttl [Numeric, nil] optional TTL override (nil preserves current TTL)
      # @return [Numeric] the new value
      # @raise [Error] when the existing value is not numeric
      def increment(key, by: 1, ttl: nil)
        @mutex.synchronize { apply_counter_delta(key, by, ttl: ttl) }
      end

      # Atomically decrement a numeric entry. See #increment.
      #
      # @param key [String] the cache key
      # @param by [Numeric] amount to subtract (default 1)
      # @param ttl [Numeric, nil] optional TTL override
      # @return [Numeric] the new value
      # @raise [Error] when the existing value is not numeric
      def decrement(key, by: 1, ttl: nil)
        @mutex.synchronize { apply_counter_delta(key, -by, ttl: ttl) }
      end

      private

      def apply_counter_delta(key, delta, ttl: nil)
        entry = @data[key]
        current, preserved_tags, preserved_ttl = counter_state(entry)
        raise Error, "value at #{key.inspect} is not numeric" unless current.is_a?(Numeric)

        new_value = current + delta
        remove_entry(key) if @data.key?(key)
        effective_ttl = ttl.nil? ? preserved_ttl : ttl
        @data[key] = Entry.new(new_value, ttl: effective_ttl, tags: preserved_tags)
        @order.push(key)
        new_value
      end

      def counter_state(entry)
        if entry.nil? || entry.expired?
          [0, [], nil]
        else
          [entry.value, entry.tags, entry.ttl]
        end
      end

      def global_stats
        { size: @data.size, hits: @hits, misses: @misses, evictions: @evictions }
      end

      def store_entry(key, value, ttl: nil, tags: [])
        remove_entry(key) if @data.key?(key)
        evict if @data.size >= @max_size
        @data[key] = Entry.new(value, ttl: ttl, tags: tags)
        @order.push(key)
        value
      end

      def fetch_or_compute(key, ttl: nil, tags: [], &block)
        value = fetch_entry(key)
        return value unless value.nil?

        computed = block.call
        store_entry(key, computed, ttl: ttl, tags: tags)
        computed
      end

      def delete_entry(key)
        @data.key?(key).tap { remove_entry(key) }
      end

      def invalidate_by_tag(tag)
        tag_s = tag.to_s
        matched = @data.select { |_, e| e.tags.include?(tag_s) }.keys
        matched.each { |k| remove_entry(k) }
        matched.size
      end

      def key_present?(key)
        entry = @data[key]
        entry ? !entry.expired? : false
      end

      def prune_expired
        expired = @data.select { |_, e| e.expired? }.keys
        expired.each { |k| evict_entry(k) }
        expired.size
      end
    end
  end
end
