# philiprehberger-cache_kit

[![Tests](https://github.com/philiprehberger/rb-cache-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-cache-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-cache_kit.svg)](https://rubygems.org/gems/philiprehberger-cache_kit)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-cache-kit)](https://github.com/philiprehberger/rb-cache-kit/commits/main)

In-memory LRU cache with TTL, tags, and thread safety

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-cache_kit"
```

Or install directly:

```bash
gem install philiprehberger-cache_kit
```

## Usage

```ruby
require "philiprehberger/cache_kit"

cache = Philiprehberger::CacheKit::Store.new(max_size: 500)

# Basic get/set
cache.set("user:1", { name: "Alice" }, ttl: 300)
cache.get("user:1") # => { name: "Alice" }
```

### Fetch (compute-on-miss)

Thread-safe get-or-compute. The block is only called if the key is missing or expired, and the entire operation holds the lock to prevent duplicate computation.

```ruby
user = cache.fetch("user:1", ttl: 300) do
  User.find(1) # only called on cache miss
end
```

### TTL Expiration

```ruby
cache.set("session", "abc", ttl: 60) # expires in 60 seconds
cache.get("session")                  # => "abc"
# ... 60 seconds later ...
cache.get("session")                  # => nil
```

### Tag-based Invalidation

```ruby
cache.set("user:1", data1, tags: ["users"])
cache.set("user:2", data2, tags: ["users"])
cache.set("post:1", data3, tags: ["posts"])

cache.invalidate_tag("users") # removes user:1 and user:2, keeps post:1
```

### Eviction Callback

Register hooks that fire when entries are evicted by LRU pressure or TTL expiry.

```ruby
cache.on_evict do |key, value|
  logger.info("Evicted #{key}")
end

# Fires on LRU eviction
cache.set("overflow", "data") # triggers callback if cache is full

# Fires on TTL expiry (during get or prune)
cache.prune
```

### Batch Get

Retrieve multiple keys in a single lock acquisition. Returns a hash of found entries only, skipping misses.

```ruby
cache.set("a", 1)
cache.set("b", 2)

cache.get_many("a", "b", "missing")
# => { "a" => 1, "b" => 2 }
```

### Bulk Set

```ruby
cache.set_many({ 'a' => 1, 'b' => 2, 'c' => 3 }, ttl: 300, tags: ['batch'])
```

### Compact

```ruby
evicted = cache.compact  # => 3 (number of expired entries removed)
```

### Refresh

```ruby
cache.refresh('key', ttl: 600)  # => true (reset TTL without changing value)
```

### Touch

Promote a key to most-recently-used in LRU order, shielding it from the next
eviction. Pass `ttl:` to also reset the entry's expiry to `now + ttl` seconds.
Returns `true` for live keys and `false` when the key is missing or expired
(expired keys are removed as a side effect).

```ruby
cache.set('a', 1)
cache.set('b', 2)
cache.set('c', 3)

cache.touch('a')           # => true ('a' is now most recently used)
cache.touch('missing')     # => false

cache.touch('a', ttl: 600) # => true (also resets TTL to 600s)
```

### Hash-like Access

```ruby
cache["user:1"] = { name: "Alice" }
cache["user:1"] # => { name: "Alice" }
```

### LRU Eviction

```ruby
cache = Philiprehberger::CacheKit::Store.new(max_size: 3)

cache.set("a", 1)
cache.set("b", 2)
cache.set("c", 3)
cache.set("d", 4) # evicts "a" (least recently used)

cache.get("a") # => nil
cache.get("d") # => 4
```

### Pruning Expired Entries

```ruby
cache.set("a", 1, ttl: 1)
cache.set("b", 2, ttl: 1)
cache.set("c", 3)
# ... after TTL expires ...
cache.prune # => 2 (removed expired entries)
```

### Stats

```ruby
cache.set("a", 1)
cache.get("a")       # hit
cache.get("missing") # miss

cache.stats
# => { size: 1, hits: 1, misses: 1, evictions: 0 }
```

### Stats by Tag

Track per-tag hit, miss, and eviction counters.

```ruby
cache.set("user:1", data, tags: ["users"])
cache.set("post:1", data, tags: ["posts"])
cache.get("user:1") # hit on "users" tag

cache.stats(tag: "users")
# => { hits: 1, misses: 0, evictions: 0 }

cache.stats(tag: "posts")
# => { hits: 0, misses: 0, evictions: 0 }
```

### TTL Introspection

Read the remaining or absolute expiration without consuming the entry.

```ruby
cache.set("session", "abc", ttl: 60)

cache.ttl("session")       # => 59.87 (Float seconds)
cache.expire_at("session") # => 2026-04-14 14:41:23 +0000 (Time)

cache.set("permanent", "x")
cache.ttl("permanent")     # => nil (no TTL)
cache.ttl("missing")       # => nil
```

### Bulk Delete

```ruby
cache.set("a", 1)
cache.set("b", 2)
cache.set("c", 3)

cache.delete_many("a", "b", "missing") # => 2 (count actually removed)
cache.keys                              # => ["c"]
```

### Values

Inspect all non-expired values without affecting LRU order.

```ruby
cache.set('a', 1)
cache.set('b', 2)
cache.set('c', 3, ttl: 0.05)
sleep 0.1

cache.values # => [1, 2] (expired 'c' excluded; LRU order untouched)
```

### Keys by Tag

Inspect which keys carry a tag without invalidating them.

```ruby
cache.set("user:1", data1, tags: ["users"])
cache.set("user:2", data2, tags: ["users"])
cache.set("post:1", data3, tags: ["posts"])

cache.keys_by_tag("users") # => ["user:1", "user:2"]
cache.keys_by_tag(:users)  # => ["user:1", "user:2"]
cache.keys_by_tag("none")  # => []
```

### Atomic Counters

Atomically increment and decrement numeric entries. Missing or expired keys
are initialized to 0 before the delta is applied.

```ruby
cache.increment("views")             # => 1
cache.increment("views")             # => 2
cache.increment("views", by: 5)      # => 7
cache.increment("views", ttl: 3600)  # => 8 (and resets TTL to 3600s)

cache.decrement("quota", by: 2)      # => -2 (if "quota" was missing)
```

Non-numeric values raise `Philiprehberger::CacheKit::Error`.

### Optimistic Locking

`replace_if_equal` atomically swaps a value only when the current entry matches the expected value, enabling compare-and-swap workflows without external coordination.

```ruby
cache.set("flag", "off")
cache.replace_if_equal("flag", "off", "on")  # => true
cache.replace_if_equal("flag", "off", "on")  # => false (value is now "on")
```

Returns `true` on a successful swap and `false` when the key is missing, expired, or holds a different value. Existing tags are preserved; pass `ttl:` to refresh the expiration at the same time.

### Snapshot and Restore

Serialize cache state for warm restarts. The snapshot captures all entries with their remaining TTL, tags, and LRU order.

```ruby
# Save state before shutdown
data = cache.snapshot
File.write("cache.bin", Marshal.dump(data))

# Restore on startup
new_cache = Philiprehberger::CacheKit::Store.new(max_size: 500)
new_cache.restore(Marshal.load(File.read("cache.bin")))
```

## API

| Method | Description |
|--------|-------------|
| `Store.new(max_size: 1000)` | Create a cache with max entries |
| `Store#get(key)` | Get a value (nil if missing/expired) |
| `Store#set(key, value, ttl:, tags:)` | Store a value |
| `Store#fetch(key, ttl:, tags:, &block)` | Get or compute a value (thread-safe) |
| `Store#delete(key)` | Delete a key |
| `Store#invalidate_tag(tag)` | Remove all entries with a tag |
| `Store#clear` | Remove all entries |
| `Store#size` | Number of entries |
| `Store#key?(key)` | Check if a key exists and is not expired |
| `Store#keys` | Returns all non-expired keys |
| `Store#values` | Returns all non-expired values (does not affect LRU order) |
| `Store#[](key)` | Hash-like read (alias for `get`) |
| `Store#[]=(key, value)` | Hash-like write (alias for `set` without TTL/tags) |
| `Store#stats` | Returns `{ size:, hits:, misses:, evictions: }` |
| `Store#stats(tag: name)` | Returns `{ hits:, misses:, evictions: }` for a tag |
| `Store#prune` | Remove all expired entries, returns count removed |
| `Store#on_evict { \|key, value\| }` | Register eviction callback |
| `Store#get_many(*keys)` | Batch get, returns `{ key => value }` for found entries |
| `#set_many(hash, ttl:, tags:)` | Bulk set multiple entries |
| `#compact` | Prune expired entries, return eviction count |
| `#refresh(key, ttl:)` | Reset TTL without changing value |
| `Store#touch(key, ttl:)` | Promote a key to most-recently-used; optionally reset TTL |
| `Store#snapshot` | Serialize cache state to a hash |
| `Store#restore(data)` | Restore cache state from a snapshot |
| `Store#ttl(key)` | Remaining seconds until expiry (nil if none/missing/expired) |
| `Store#expire_at(key)` | Absolute expiration `Time` (nil if none/missing/expired) |
| `Store#delete_many(*keys)` | Bulk-delete, returns count removed |
| `Store#keys_by_tag(tag)` | Keys associated with a tag (non-expired) |
| `Store#increment(key, by:, ttl:)` | Atomic numeric increment |
| `Store#decrement(key, by:, ttl:)` | Atomic numeric decrement |
| `Store#replace_if_equal(key, expected, new_value, ttl:)` | Compare-and-swap; returns `true` on a successful swap, `false` otherwise |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-cache-kit)

🐛 [Report issues](https://github.com/philiprehberger/rb-cache-kit/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-cache-kit/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
