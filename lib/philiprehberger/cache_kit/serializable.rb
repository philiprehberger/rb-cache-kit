# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Snapshot and restore support for Store.
    module Serializable
      # Serialize current cache state for persistence.
      #
      # @return [Hash] serialized cache data
      def snapshot
        @mutex.synchronize { build_snapshot }
      end

      # Restore cache state from a previous snapshot.
      #
      # @param data [Hash] snapshot data from #snapshot
      # @return [void]
      def restore(data)
        @mutex.synchronize { apply_snapshot(data) }
      end

      private

      def build_snapshot
        entries = @data.transform_values { |e| serialize_entry(e) }
        { entries: entries, order: @order.dup }
      end

      def serialize_entry(entry)
        { value: entry.value, ttl: remaining_ttl(entry), tags: entry.tags }
      end

      def remaining_ttl(entry)
        original = entry.instance_variable_get(:@ttl)
        return nil if original.nil?

        remaining = original - (Time.now - entry.created_at)
        remaining.positive? ? remaining : 0
      end

      def apply_snapshot(data)
        @data.clear
        @order.clear
        restore_entries(data[:entries])
        @order.replace(data[:order].select { |k| @data.key?(k) })
      end

      def restore_entries(entries)
        entries.each do |key, attrs|
          next if attrs[:ttl]&.zero?

          @data[key] = Entry.new(attrs[:value], ttl: attrs[:ttl], tags: attrs[:tags] || [])
        end
      end
    end
  end
end
