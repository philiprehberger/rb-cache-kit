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
      expect(cache.stats[:hits]).to eq(0)
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
end
