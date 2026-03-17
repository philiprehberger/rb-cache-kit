# frozen_string_literal: true

module Philiprehberger
  module CacheKit
    # Per-tag hit/miss/eviction tracking for Store.
    module TagStats
      private

      def init_tag_stats
        @tag_hits = Hash.new(0)
        @tag_misses = Hash.new(0)
        @tag_evictions = Hash.new(0)
      end

      def record_tag_hit(entry)
        entry.tags.each { |t| @tag_hits[t] += 1 }
      end

      def record_tag_miss_for(key)
        find_tags_for_key(key).each { |t| @tag_misses[t] += 1 }
      end

      def record_tag_eviction(entry)
        entry.tags.each { |t| @tag_evictions[t] += 1 }
      end

      def find_tags_for_key(key)
        entry = @data[key]
        entry ? entry.tags : []
      end

      def tag_stats_for(tag)
        tag_s = tag.to_s
        {
          hits: @tag_hits[tag_s],
          misses: @tag_misses[tag_s],
          evictions: @tag_evictions[tag_s]
        }
      end
    end
  end
end
