# frozen_string_literal: true

require_relative 'lib/philiprehberger/cache_kit/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-cache_kit'
  spec.version = Philiprehberger::CacheKit::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'In-memory LRU cache with TTL, tags, and thread safety'
  spec.description = 'A lightweight, thread-safe in-memory LRU cache with TTL expiration ' \
                     'and tag-based bulk invalidation for Ruby applications.'
  spec.homepage      = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-cache_kit'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri']       = 'https://github.com/philiprehberger/rb-cache-kit'
  spec.metadata['changelog_uri']         = 'https://github.com/philiprehberger/rb-cache-kit/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri']       = 'https://github.com/philiprehberger/rb-cache-kit/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
