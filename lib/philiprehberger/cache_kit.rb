# frozen_string_literal: true

require_relative 'cache_kit/version'
require_relative 'cache_kit/entry'
require_relative 'cache_kit/callbacks'
require_relative 'cache_kit/tag_stats'
require_relative 'cache_kit/batch'
require_relative 'cache_kit/serializable'
require_relative 'cache_kit/eviction'
require_relative 'cache_kit/store'

module Philiprehberger
  module CacheKit
    class Error < StandardError; end
  end
end
