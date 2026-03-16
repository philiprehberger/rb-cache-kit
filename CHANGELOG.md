# Changelog

## 0.2.2

- Add License badge to README
- Add bug_tracker_uri to gemspec

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-03-13

### Fixed
- Fix SyntaxError: setter method `[]=` cannot use endless method definition

## [0.2.0] - 2026-03-13

### Added
- `keys` method returns all non-expired cache keys
- `[]` and `[]=` hash-like accessors for get/set
- `stats` method returns size, hits, misses, and eviction counts
- `prune` method removes all expired entries and returns count removed
- Hit/miss/eviction tracking counters (thread-safe)

## [0.1.0] - 2026-03-10

### Added
- Initial release
- Thread-safe in-memory LRU cache
- TTL expiration per entry
- Tag-based bulk invalidation
- `get`, `set`, `fetch`, `delete`, `clear` operations
- Configurable max size with LRU eviction
