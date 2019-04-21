# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.3.1] - 2026-03-22

### Changed
- Update rubocop configuration for Windows compatibility

## [0.3.0] - 2026-03-17

### Added
- Thread-safe `fetch` — compute-on-miss now holds the lock for the entire operation, preventing duplicate computation
- Eviction callbacks via `on_evict { |key, value| ... }` — fires on LRU eviction and TTL expiry
- Per-tag statistics via `stats(tag: :name)` — returns `{ hits:, misses:, evictions: }` for a specific tag
- Batch retrieval via `get_many(keys)` — fetch multiple keys in a single lock acquisition, returns a hash
- Snapshot and restore via `snapshot` / `restore(data)` — serialize and deserialize cache state for warm restarts

## [0.2.2] - 2026-03-16

### Changed
- Add License badge to README
- Add bug_tracker_uri to gemspec

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
