# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.11.0] - 2026-05-02

### Added
- `Store#tags` — sorted list of all tags currently in use across non-expired entries, complementing `keys_by_tag` and `stats(tag:)` for tag discovery

## [0.10.0] - 2026-04-28

### Added
- `Store#peek(key)` — read a value without affecting LRU order or hit/miss counters. Returns `nil` for missing or expired entries. Does not remove expired entries (use `#prune` or `#get` for that).

## [0.9.0] - 2026-04-20

### Added
- `Store#replace_if_equal(key, expected, new_value, ttl: nil)` — compare-and-swap primitive for optimistic locking. Atomically replaces the stored value only when it matches `expected`, preserving existing tags and (optionally) refreshing the TTL. Returns `true` on a successful swap, `false` otherwise.

## [0.8.0] - 2026-04-18

### Added
- `Store#touch(key, ttl: nil)` — promotes a key to most-recently-used in LRU order and optionally resets TTL; returns `true` for live keys, `false` for missing or expired keys

## [0.7.0] - 2026-04-15

### Added
- `#values` returns an array of all non-expired values currently in the cache; read-only introspection that does not affect LRU ordering

## [0.6.1] - 2026-04-15

### Fixed
- Correct `homepage` URL in gemspec to use hyphenated slug (`philiprehberger-cache-kit`) matching the portfolio package page

## [0.6.0] - 2026-04-14

### Added
- `#ttl(key)` returns remaining seconds until expiry (nil if no TTL, missing, or expired)
- `#expire_at(key)` returns absolute expiration `Time` (nil if no TTL, missing, or expired)
- `#delete_many(*keys)` bulk-deletes multiple keys in a single lock acquisition; returns count removed
- `#keys_by_tag(tag)` returns the keys associated with a tag (non-expired only)
- `#increment(key, by: 1, ttl: nil)` atomic numeric increment with optional TTL override
- `#decrement(key, by: 1, ttl: nil)` atomic numeric decrement

### Changed
- Align `.github/ISSUE_TEMPLATE/bug_report.yml` and `feature_request.yml` with the latest issue-template guide (required fields, field order, reproduction/proposed-api placeholders)

## [0.5.0] - 2026-04-04

### Changed
- `#get_many` now accepts splat args (`get_many(*keys)`) and skips misses, returning only found entries

### Added
- `gem-version` field to bug report issue template
- `Alternatives considered` textarea to feature request issue template

## [0.4.0] - 2026-04-01

### Added
- `#set_many(hash, ttl:, tags:)` for bulk setting multiple entries
- `#compact` for pruning expired entries with eviction count
- `#refresh(key, ttl:)` for resetting TTL without changing value

## [0.3.7] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.3.6] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.3.5] - 2026-03-26

### Changed

- Add Sponsor badge and fix License link format in README

## [0.3.4] - 2026-03-24

### Changed
- Expand test coverage to 65+ examples covering edge cases and error paths

## [0.3.3] - 2026-03-24

### Fixed
- Fix README one-liner to remove trailing period and match gemspec summary

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
