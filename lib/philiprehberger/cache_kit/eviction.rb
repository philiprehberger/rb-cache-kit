# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Internal eviction and entry management for Store.
    module Eviction
      private

      def promote_key(key)
        @order.delete(key)
        @order.push(key)
      end

      def fetch_entry(key)
        entry = @data[key]
        return record_miss(key) unless entry
        return expire_and_miss(key) if entry.expired?

        @hits += 1
        record_tag_hit(entry)
        promote_key(key)
        entry.value
      end

      def record_miss(key)
        @misses += 1
        record_tag_miss_for(key)
        nil
      end

      def expire_and_miss(key)
        evict_entry(key)
        @misses += 1
        nil
      end

      def evict
        oldest = @order.first
        return unless oldest

        evict_entry(oldest)
      end

      def evict_entry(key)
        entry = @data[key]
        return unless entry

        fire_evict(key, entry.value)
        record_tag_eviction(entry)
        @evictions += 1
        remove_entry(key)
      end

      def remove_entry(key)
        @data.delete(key)
        @order.delete(key)
      end
    end
  end
end
