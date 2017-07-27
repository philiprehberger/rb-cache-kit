# frozen_string_literal: true

require "spec_helper"

RSpec.describe Philiprehberger::CacheKit do
  it "has a version number" do
    expect(Philiprehberger::CacheKit::VERSION).not_to be_nil
  end
end

RSpec.describe Philiprehberger::CacheKit::Store do
  subject(:cache) { described_class.new(max_size: 5) }

  describe "#set and #get" do
    it "stores and retrieves values" do
      cache.set("key", "value")
      expect(cache.get("key")).to eq("value")
    end

    it "returns nil for missing keys" do
      expect(cache.get("missing")).to be_nil
    end

    it "overwrites existing keys" do
      cache.set("key", "old")
      cache.set("key", "new")
      expect(cache.get("key")).to eq("new")
    end
  end

  describe "TTL" do
    it "returns nil for expired entries" do
      cache.set("key", "value", ttl: 0.05)
      expect(cache.get("key")).to eq("value")
      sleep 0.1
      expect(cache.get("key")).to be_nil
    end

    it "keeps entries without TTL indefinitely" do
      cache.set("key", "value")
      expect(cache.get("key")).to eq("value")
    end
  end

  describe "#fetch" do
    it "returns cached value if present" do
      cache.set("key", "cached")
      result = cache.fetch("key") { "computed" }
      expect(result).to eq("cached")
    end

    it "computes and stores value if missing" do
      result = cache.fetch("key", ttl: 60) { "computed" }
      expect(result).to eq("computed")
      expect(cache.get("key")).to eq("computed")
    end

    it "is thread-safe during concurrent fetch" do
      call_count = 0
      mutex = Mutex.new
      threads = 10.times.map do
        Thread.new do
          cache.fetch("shared", ttl: 60) do
            mutex.synchronize { call_count += 1 }
            "result"
          end
        end
      end
      threads.each(&:join)
      expect(cache.get("shared")).to eq("result")
    end

    it "accepts tags for computed values" do
      cache.fetch("key", ttl: 60, tags: ["group"]) { "val" }
      removed = cache.invalidate_tag("group")
      expect(removed).to eq(1)
    end
  end

  describe "#delete" do
    it "removes a key" do
      cache.set("key", "value")
      expect(cache.delete("key")).to be true
      expect(cache.get("key")).to be_nil
    end

    it "returns false for missing keys" do
      expect(cache.delete("missing")).to be false
    end
  end

  describe "#invalidate_tag" do
    it "removes all entries with the given tag" do
      cache.set("a", 1, tags: ["group1"])
      cache.set("b", 2, tags: ["group1"])
      cache.set("c", 3, tags: ["group2"])

      removed = cache.invalidate_tag("group1")

      expect(removed).to eq(2)
      expect(cache.get("a")).to be_nil
      expect(cache.get("b")).to be_nil
      expect(cache.get("c")).to eq(3)
    end
  end

  describe "LRU eviction" do
    it "evicts the least recently used entry when full" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3)
      cache.set("d", 4)
      cache.set("e", 5)

      # Cache is full (max_size: 5), adding one more should evict "a"
      cache.set("f", 6)
      expect(cache.get("a")).to be_nil
      expect(cache.get("f")).to eq(6)
    end

    it "touching a key moves it to most recently used" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3)
      cache.set("d", 4)
      cache.set("e", 5)

      # Touch "a" by reading it
      cache.get("a")

      # Now "b" is the LRU
      cache.set("f", 6)
      expect(cache.get("a")).to eq(1)
      expect(cache.get("b")).to be_nil
    end
  end

  describe "#clear" do
    it "removes all entries" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.clear
      expect(cache.size).to eq(0)
    end
  end

  describe "#size" do
    it "returns the number of entries" do
      expect(cache.size).to eq(0)
      cache.set("a", 1)
      expect(cache.size).to eq(1)
    end
  end

  describe "#key?" do
    it "returns true for existing non-expired keys" do
      cache.set("a", 1)
      expect(cache.key?("a")).to be true
    end

    it "returns false for missing keys" do
      expect(cache.key?("missing")).to be false
    end

    it "returns false for expired keys" do
      cache.set("a", 1, ttl: 0.05)
      sleep 0.1
      expect(cache.key?("a")).to be false
    end
  end

  describe "#keys" do
    it "returns all non-expired keys" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3, ttl: 0.05)
      sleep 0.1
      expect(cache.keys).to contain_exactly("a", "b")
    end

    it "returns an empty array when cache is empty" do
      expect(cache.keys).to eq([])
    end
  end

  describe "#[] and #[]=" do
    it "reads values with []" do
      cache.set("key", "value")
      expect(cache["key"]).to eq("value")
    end

    it "returns nil for missing keys with []" do
      expect(cache["missing"]).to be_nil
    end

    it "writes values with []=" do
      cache["key"] = "value"
      expect(cache.get("key")).to eq("value")
    end
  end

  describe "#stats" do
    it "returns size, hits, misses, and evictions" do
      cache.set("a", 1)
      cache.get("a")
      cache.get("missing")

      stats = cache.stats
      expect(stats[:size]).to eq(1)
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
      expect(stats[:evictions]).to eq(0)
    end

    it "tracks evictions" do
      5.times { |i| cache.set("k#{i}", i) }
      cache.set("extra", 99)

      expect(cache.stats[:evictions]).to eq(1)
    end

    it "counts expired gets as misses" do
      cache.set("a", 1, ttl: 0.05)
      sleep 0.1
      cache.get("a")

      expect(cache.stats[:misses]).to eq(1)
    end
  end

  describe "#prune" do
    it "removes all expired entries and returns count" do
      cache.set("a", 1, ttl: 0.05)
      cache.set("b", 2, ttl: 0.05)
      cache.set("c", 3)
      sleep 0.1

      removed = cache.prune
      expect(removed).to eq(2)
      expect(cache.size).to eq(1)
      expect(cache.get("c")).to eq(3)
    end

    it "returns zero when nothing is expired" do
      cache.set("a", 1)
      expect(cache.prune).to eq(0)
    end
  end

  describe "#on_evict" do
    it "calls the callback on LRU eviction" do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      5.times { |i| cache.set("k#{i}", i) }
      cache.set("extra", 99)

      expect(evicted).to eq([["k0", 0]])
    end

    it "calls the callback on TTL expiry during get" do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set("temp", "data", ttl: 0.05)
      sleep 0.1
      cache.get("temp")

      expect(evicted).to eq([%w[temp data]])
    end

    it "calls the callback on TTL expiry during prune" do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set("a", 1, ttl: 0.05)
      cache.set("b", 2, ttl: 0.05)
      sleep 0.1
      cache.prune

      expect(evicted).to contain_exactly(["a", 1], ["b", 2])
    end

    it "supports multiple callbacks" do
      results_a = []
      results_b = []
      cache.on_evict { |key, _| results_a << key }
      cache.on_evict { |key, _| results_b << key }

      5.times { |i| cache.set("k#{i}", i) }
      cache.set("extra", 99)

      expect(results_a).to eq(["k0"])
      expect(results_b).to eq(["k0"])
    end

    it "does not fire on explicit delete" do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set("key", "value")
      cache.delete("key")

      expect(evicted).to be_empty
    end
  end

  describe "#stats with tag:" do
    it "returns per-tag hit counters" do
      cache.set("u1", 1, tags: ["users"])
      cache.set("u2", 2, tags: ["users"])
      cache.get("u1")
      cache.get("u2")

      tag_stats = cache.stats(tag: "users")
      expect(tag_stats[:hits]).to eq(2)
    end

    it "returns per-tag miss counters" do
      cache.set("u1", 1, tags: ["users"])
      sleep 0.1
      # Fetch a key that does not exist — records a miss (no tags to attribute)
      cache.get("nonexistent")

      tag_stats = cache.stats(tag: "users")
      expect(tag_stats[:misses]).to eq(0)
    end

    it "returns per-tag eviction counters" do
      cache.set("u1", 1, tags: ["users"])
      cache.set("u2", 2, tags: ["users"])
      cache.set("p1", 3, tags: ["posts"])
      cache.set("k4", 4)
      cache.set("k5", 5)

      # Evict u1 (LRU)
      cache.set("k6", 6)

      user_stats = cache.stats(tag: "users")
      expect(user_stats[:evictions]).to eq(1)

      post_stats = cache.stats(tag: "posts")
      expect(post_stats[:evictions]).to eq(0)
    end

    it "tracks hits across tags for multi-tagged entries" do
      cache.set("key", "val", tags: %w[users admin])
      cache.get("key")

      expect(cache.stats(tag: "users")[:hits]).to eq(1)
      expect(cache.stats(tag: "admin")[:hits]).to eq(1)
    end

    it "works with symbol tags" do
      cache.set("u1", 1, tags: [:users])
      cache.get("u1")

      tag_stats = cache.stats(tag: :users)
      expect(tag_stats[:hits]).to eq(1)
    end
  end

  describe "#get_many" do
    it "retrieves multiple keys at once" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3)

      result = cache.get_many(%w[a b c])
      expect(result).to eq("a" => 1, "b" => 2, "c" => 3)
    end

    it "returns nil for missing keys" do
      cache.set("a", 1)

      result = cache.get_many(%w[a missing])
      expect(result).to eq("a" => 1, "missing" => nil)
    end

    it "returns nil for expired keys" do
      cache.set("a", 1, ttl: 0.05)
      cache.set("b", 2)
      sleep 0.1

      result = cache.get_many(%w[a b])
      expect(result).to eq("a" => nil, "b" => 2)
    end

    it "returns an empty hash for empty input" do
      result = cache.get_many([])
      expect(result).to eq({})
    end

    it "updates hit and miss stats correctly" do
      cache.set("a", 1)
      cache.set("b", 2)

      cache.get_many(%w[a b missing])
      stats = cache.stats
      expect(stats[:hits]).to eq(2)
      expect(stats[:misses]).to eq(1)
    end
  end

  describe "#snapshot and #restore" do
    it "round-trips cache state" do
      cache.set("a", 1, tags: ["group"])
      cache.set("b", 2, ttl: 300)
      cache.set("c", 3)

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      expect(new_cache.get("a")).to eq(1)
      expect(new_cache.get("b")).to eq(2)
      expect(new_cache.get("c")).to eq(3)
    end

    it "preserves tags after restore" do
      cache.set("a", 1, tags: ["group"])
      cache.set("b", 2, tags: ["group"])
      cache.set("c", 3)

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      removed = new_cache.invalidate_tag("group")
      expect(removed).to eq(2)
      expect(new_cache.get("c")).to eq(3)
    end

    it "preserves LRU order after restore" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3)
      cache.set("d", 4)
      cache.set("e", 5)

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      # "a" should still be LRU
      new_cache.set("f", 6)
      expect(new_cache.get("a")).to be_nil
      expect(new_cache.get("f")).to eq(6)
    end

    it "excludes already-expired entries" do
      cache.set("a", 1, ttl: 0.05)
      cache.set("b", 2)
      sleep 0.1

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      expect(new_cache.get("a")).to be_nil
      expect(new_cache.get("b")).to eq(2)
    end

    it "preserves remaining TTL" do
      cache.set("a", 1, ttl: 300)
      data = cache.snapshot

      ttl = data[:entries]["a"][:ttl]
      expect(ttl).to be_positive
      expect(ttl).to be <= 300
    end

    it "clears existing data before restore" do
      cache.set("existing", "old")

      other = described_class.new(max_size: 5)
      other.set("new", "data")
      data = other.snapshot

      cache.restore(data)
      expect(cache.get("existing")).to be_nil
      expect(cache.get("new")).to eq("data")
    end
  end
end
