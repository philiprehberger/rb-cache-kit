# philiprehberger-cache_kit

[![Tests](https://github.com/philiprehberger/rb-cache-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-cache-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-cache_kit.svg)](https://rubygems.org/gems/philiprehberger-cache_kit)

In-memory LRU cache with TTL, tags, and thread safety for Ruby.

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-cache_kit"
```

Then run:

```bash
bundle install
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

### Fetch (get or compute)

```ruby
user = cache.fetch("user:1", ttl: 300) do
  User.find(1)
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

## API

| Method | Description |
|--------|-------------|
| `Store.new(max_size: 1000)` | Create a cache with max entries |
| `Store#get(key)` | Get a value (nil if missing/expired) |
| `Store#set(key, value, ttl:, tags:)` | Store a value |
| `Store#fetch(key, ttl:, tags:, &block)` | Get or compute a value |
| `Store#delete(key)` | Delete a key |
| `Store#invalidate_tag(tag)` | Remove all entries with a tag |
| `Store#clear` | Remove all entries |
| `Store#size` | Number of entries |
| `Store#key?(key)` | Check if a key exists and is not expired |
| `Store#keys` | Returns all non-expired keys |
| `Store#[](key)` | Hash-like read (alias for `get`) |
| `Store#[]=(key, value)` | Hash-like write (alias for `set` without TTL/tags) |
| `Store#stats` | Returns `{ size:, hits:, misses:, evictions: }` |
| `Store#prune` | Remove all expired entries, returns count removed |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT
