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

Retrieve multiple keys in a single lock acquisition. Returns a hash mapping each key to its value (or nil if missing/expired).

```ruby
cache.set("a", 1)
cache.set("b", 2)

cache.get_many(["a", "b", "missing"])
# => { "a" => 1, "b" => 2, "missing" => nil }
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
| `Store#[](key)` | Hash-like read (alias for `get`) |
| `Store#[]=(key, value)` | Hash-like write (alias for `set` without TTL/tags) |
| `Store#stats` | Returns `{ size:, hits:, misses:, evictions: }` |
| `Store#stats(tag: name)` | Returns `{ hits:, misses:, evictions: }` for a tag |
| `Store#prune` | Remove all expired entries, returns count removed |
| `Store#on_evict { \|key, value\| }` | Register eviction callback |
| `Store#get_many(keys)` | Batch get, returns `{ key => value }` hash |
| `Store#snapshot` | Serialize cache state to a hash |
| `Store#restore(data)` | Restore cache state from a snapshot |

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
