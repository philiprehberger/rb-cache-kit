# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Eviction callback support for Store.
    module Callbacks
      # Register a callback invoked when entries are evicted.
      #
      # @yield [key, value] called on eviction (LRU or TTL expiry)
      # @return [void]
      def on_evict(&block)
        @mutex.synchronize { @evict_callbacks << block }
      end

      private

      def init_callbacks
        @evict_callbacks = []
      end

      def fire_evict(key, value)
        @evict_callbacks.each { |cb| cb.call(key, value) }
      end
    end
  end
end
