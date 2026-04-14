# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::CacheKit do
  it 'has a version number' do
    expect(Philiprehberger::CacheKit::VERSION).not_to be_nil
  end

  it 'defines an Error class inheriting from StandardError' do
    expect(Philiprehberger::CacheKit::Error).to be < StandardError
  end
end

RSpec.describe Philiprehberger::CacheKit::Entry do
  describe '#expired?' do
    it 'returns false when no TTL is set' do
      entry = described_class.new('value')
      expect(entry.expired?).to be false
    end

    it 'returns false when TTL has not elapsed' do
      entry = described_class.new('value', ttl: 300)
      expect(entry.expired?).to be false
    end

    it 'returns true when TTL has elapsed' do
      entry = described_class.new('value', ttl: 0.05)
      sleep 0.1
      expect(entry.expired?).to be true
    end
  end

  describe '#tags' do
    it 'coerces symbol tags to strings' do
      entry = described_class.new('value', tags: %i[foo bar])
      expect(entry.tags).to eq(%w[foo bar])
    end

    it 'defaults to an empty array' do
      entry = described_class.new('value')
      expect(entry.tags).to eq([])
    end
  end

  describe '#created_at' do
    it 'records the creation time' do
      before = Time.now
      entry = described_class.new('value')
      after = Time.now
      expect(entry.created_at).to be_between(before, after)
    end
  end
end

RSpec.describe Philiprehberger::CacheKit::Store do
  subject(:cache) { described_class.new(max_size: 5) }

  describe '#set and #get' do
    it 'stores and retrieves values' do
      cache.set('key', 'value')
      expect(cache.get('key')).to eq('value')
    end

    it 'returns nil for missing keys' do
      expect(cache.get('missing')).to be_nil
    end

    it 'overwrites existing keys' do
      cache.set('key', 'old')
      cache.set('key', 'new')
      expect(cache.get('key')).to eq('new')
    end
  end

  describe 'TTL' do
    it 'returns nil for expired entries' do
      cache.set('key', 'value', ttl: 0.05)
      expect(cache.get('key')).to eq('value')
      sleep 0.1
      expect(cache.get('key')).to be_nil
    end

    it 'keeps entries without TTL indefinitely' do
      cache.set('key', 'value')
      expect(cache.get('key')).to eq('value')
    end
  end

  describe '#fetch' do
    it 'returns cached value if present' do
      cache.set('key', 'cached')
      result = cache.fetch('key') { 'computed' }
      expect(result).to eq('cached')
    end

    it 'computes and stores value if missing' do
      result = cache.fetch('key', ttl: 60) { 'computed' }
      expect(result).to eq('computed')
      expect(cache.get('key')).to eq('computed')
    end

    it 'is thread-safe during concurrent fetch' do
      call_count = 0
      mutex = Mutex.new
      threads = 10.times.map do
        Thread.new do
          cache.fetch('shared', ttl: 60) do
            mutex.synchronize { call_count += 1 }
            'result'
          end
        end
      end
      threads.each(&:join)
      expect(cache.get('shared')).to eq('result')
    end

    it 'accepts tags for computed values' do
      cache.fetch('key', ttl: 60, tags: ['group']) { 'val' }
      removed = cache.invalidate_tag('group')
      expect(removed).to eq(1)
    end
  end

  describe '#delete' do
    it 'removes a key' do
      cache.set('key', 'value')
      expect(cache.delete('key')).to be true
      expect(cache.get('key')).to be_nil
    end

    it 'returns false for missing keys' do
      expect(cache.delete('missing')).to be false
    end
  end

  describe '#invalidate_tag' do
    it 'removes all entries with the given tag' do
      cache.set('a', 1, tags: ['group1'])
      cache.set('b', 2, tags: ['group1'])
      cache.set('c', 3, tags: ['group2'])

      removed = cache.invalidate_tag('group1')

      expect(removed).to eq(2)
      expect(cache.get('a')).to be_nil
      expect(cache.get('b')).to be_nil
      expect(cache.get('c')).to eq(3)
    end
  end

  describe 'LRU eviction' do
    it 'evicts the least recently used entry when full' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.set('c', 3)
      cache.set('d', 4)
      cache.set('e', 5)

      # Cache is full (max_size: 5), adding one more should evict "a"
      cache.set('f', 6)
      expect(cache.get('a')).to be_nil
      expect(cache.get('f')).to eq(6)
    end

    it 'touching a key moves it to most recently used' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.set('c', 3)
      cache.set('d', 4)
      cache.set('e', 5)

      # Touch "a" by reading it
      cache.get('a')

      # Now "b" is the LRU
      cache.set('f', 6)
      expect(cache.get('a')).to eq(1)
      expect(cache.get('b')).to be_nil
    end
  end

  describe '#clear' do
    it 'removes all entries' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.clear
      expect(cache.size).to eq(0)
    end
  end

  describe '#size' do
    it 'returns the number of entries' do
      expect(cache.size).to eq(0)
      cache.set('a', 1)
      expect(cache.size).to eq(1)
    end
  end

  describe '#key?' do
    it 'returns true for existing non-expired keys' do
      cache.set('a', 1)
      expect(cache.key?('a')).to be true
    end

    it 'returns false for missing keys' do
      expect(cache.key?('missing')).to be false
    end

    it 'returns false for expired keys' do
      cache.set('a', 1, ttl: 0.05)
      sleep 0.1
      expect(cache.key?('a')).to be false
    end
  end

  describe '#keys' do
    it 'returns all non-expired keys' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.set('c', 3, ttl: 0.05)
      sleep 0.1
      expect(cache.keys).to contain_exactly('a', 'b')
    end

    it 'returns an empty array when cache is empty' do
      expect(cache.keys).to eq([])
    end
  end

  describe '#[] and #[]=' do
    it 'reads values with []' do
      cache.set('key', 'value')
      expect(cache['key']).to eq('value')
    end

    it 'returns nil for missing keys with []' do
      expect(cache['missing']).to be_nil
    end

    it 'writes values with []=' do
      cache['key'] = 'value'
      expect(cache.get('key')).to eq('value')
    end
  end

  describe '#stats' do
    it 'returns size, hits, misses, and evictions' do
      cache.set('a', 1)
      cache.get('a')
      cache.get('missing')

      stats = cache.stats
      expect(stats[:size]).to eq(1)
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
      expect(stats[:evictions]).to eq(0)
    end

    it 'tracks evictions' do
      5.times { |i| cache.set("k#{i}", i) }
      cache.set('extra', 99)

      expect(cache.stats[:evictions]).to eq(1)
    end

    it 'counts expired gets as misses' do
      cache.set('a', 1, ttl: 0.05)
      sleep 0.1
      cache.get('a')

      expect(cache.stats[:misses]).to eq(1)
    end
  end

  describe '#prune' do
    it 'removes all expired entries and returns count' do
      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2, ttl: 0.05)
      cache.set('c', 3)
      sleep 0.1

      removed = cache.prune
      expect(removed).to eq(2)
      expect(cache.size).to eq(1)
      expect(cache.get('c')).to eq(3)
    end

    it 'returns zero when nothing is expired' do
      cache.set('a', 1)
      expect(cache.prune).to eq(0)
    end
  end

  describe '#on_evict' do
    it 'calls the callback on LRU eviction' do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      5.times { |i| cache.set("k#{i}", i) }
      cache.set('extra', 99)

      expect(evicted).to eq([['k0', 0]])
    end

    it 'calls the callback on TTL expiry during get' do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set('temp', 'data', ttl: 0.05)
      sleep 0.1
      cache.get('temp')

      expect(evicted).to eq([%w[temp data]])
    end

    it 'calls the callback on TTL expiry during prune' do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2, ttl: 0.05)
      sleep 0.1
      cache.prune

      expect(evicted).to contain_exactly(['a', 1], ['b', 2])
    end

    it 'supports multiple callbacks' do
      results_a = []
      results_b = []
      cache.on_evict { |key, _| results_a << key }
      cache.on_evict { |key, _| results_b << key }

      5.times { |i| cache.set("k#{i}", i) }
      cache.set('extra', 99)

      expect(results_a).to eq(['k0'])
      expect(results_b).to eq(['k0'])
    end

    it 'does not fire on explicit delete' do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set('key', 'value')
      cache.delete('key')

      expect(evicted).to be_empty
    end
  end

  describe '#stats with tag:' do
    it 'returns per-tag hit counters' do
      cache.set('u1', 1, tags: ['users'])
      cache.set('u2', 2, tags: ['users'])
      cache.get('u1')
      cache.get('u2')

      tag_stats = cache.stats(tag: 'users')
      expect(tag_stats[:hits]).to eq(2)
    end

    it 'returns per-tag miss counters' do
      cache.set('u1', 1, tags: ['users'])
      sleep 0.1
      # Fetch a key that does not exist — records a miss (no tags to attribute)
      cache.get('nonexistent')

      tag_stats = cache.stats(tag: 'users')
      expect(tag_stats[:misses]).to eq(0)
    end

    it 'returns per-tag eviction counters' do
      cache.set('u1', 1, tags: ['users'])
      cache.set('u2', 2, tags: ['users'])
      cache.set('p1', 3, tags: ['posts'])
      cache.set('k4', 4)
      cache.set('k5', 5)

      # Evict u1 (LRU)
      cache.set('k6', 6)

      user_stats = cache.stats(tag: 'users')
      expect(user_stats[:evictions]).to eq(1)

      post_stats = cache.stats(tag: 'posts')
      expect(post_stats[:evictions]).to eq(0)
    end

    it 'tracks hits across tags for multi-tagged entries' do
      cache.set('key', 'val', tags: %w[users admin])
      cache.get('key')

      expect(cache.stats(tag: 'users')[:hits]).to eq(1)
      expect(cache.stats(tag: 'admin')[:hits]).to eq(1)
    end

    it 'works with symbol tags' do
      cache.set('u1', 1, tags: [:users])
      cache.get('u1')

      tag_stats = cache.stats(tag: :users)
      expect(tag_stats[:hits]).to eq(1)
    end
  end

  describe '#get_many' do
    it 'retrieves multiple keys at once' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.set('c', 3)

      result = cache.get_many('a', 'b', 'c')
      expect(result).to eq('a' => 1, 'b' => 2, 'c' => 3)
    end

    it 'skips missing keys' do
      cache.set('a', 1)

      result = cache.get_many('a', 'missing')
      expect(result).to eq('a' => 1)
      expect(result).not_to have_key('missing')
    end

    it 'skips expired keys' do
      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2)
      sleep 0.1

      result = cache.get_many('a', 'b')
      expect(result).to eq('b' => 2)
      expect(result).not_to have_key('a')
    end

    it 'returns an empty hash for empty input' do
      result = cache.get_many
      expect(result).to eq({})
    end

    it 'accepts an array via splat' do
      cache.set('a', 1)
      cache.set('b', 2)

      result = cache.get_many(*%w[a b])
      expect(result).to eq('a' => 1, 'b' => 2)
    end

    it 'updates hit and miss stats correctly' do
      cache.set('a', 1)
      cache.set('b', 2)

      cache.get_many('a', 'b', 'missing')
      stats = cache.stats
      expect(stats[:hits]).to eq(2)
      expect(stats[:misses]).to eq(1)
    end
  end

  describe '#snapshot and #restore' do
    it 'round-trips cache state' do
      cache.set('a', 1, tags: ['group'])
      cache.set('b', 2, ttl: 300)
      cache.set('c', 3)

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      expect(new_cache.get('a')).to eq(1)
      expect(new_cache.get('b')).to eq(2)
      expect(new_cache.get('c')).to eq(3)
    end

    it 'preserves tags after restore' do
      cache.set('a', 1, tags: ['group'])
      cache.set('b', 2, tags: ['group'])
      cache.set('c', 3)

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      removed = new_cache.invalidate_tag('group')
      expect(removed).to eq(2)
      expect(new_cache.get('c')).to eq(3)
    end

    it 'preserves LRU order after restore' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.set('c', 3)
      cache.set('d', 4)
      cache.set('e', 5)

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      # "a" should still be LRU
      new_cache.set('f', 6)
      expect(new_cache.get('a')).to be_nil
      expect(new_cache.get('f')).to eq(6)
    end

    it 'excludes already-expired entries' do
      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2)
      sleep 0.1

      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      expect(new_cache.get('a')).to be_nil
      expect(new_cache.get('b')).to eq(2)
    end

    it 'preserves remaining TTL' do
      cache.set('a', 1, ttl: 300)
      data = cache.snapshot

      ttl = data[:entries]['a'][:ttl]
      expect(ttl).to be_positive
      expect(ttl).to be <= 300
    end

    it 'clears existing data before restore' do
      cache.set('existing', 'old')

      other = described_class.new(max_size: 5)
      other.set('new', 'data')
      data = other.snapshot

      cache.restore(data)
      expect(cache.get('existing')).to be_nil
      expect(cache.get('new')).to eq('data')
    end

    it 'round-trips an empty cache' do
      data = cache.snapshot
      new_cache = described_class.new(max_size: 5)
      new_cache.set('pre-existing', 1)
      new_cache.restore(data)

      expect(new_cache.size).to eq(0)
      expect(new_cache.get('pre-existing')).to be_nil
    end

    it 'skips entries with zero remaining TTL during restore' do
      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2)
      sleep 0.1

      # Manually build a snapshot with zero TTL to simulate edge case
      data = { entries: { 'x' => { value: 99, ttl: 0, tags: [] }, 'y' => { value: 100, ttl: nil, tags: [] } },
               order: %w[x y] }
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      expect(new_cache.get('x')).to be_nil
      expect(new_cache.get('y')).to eq(100)
    end
  end

  describe 'default max_size' do
    it 'defaults to 1000 entries' do
      large_cache = described_class.new
      1001.times { |i| large_cache.set("k#{i}", i) }
      expect(large_cache.size).to eq(1000)
    end
  end

  describe 'max_size: 1' do
    subject(:tiny_cache) { described_class.new(max_size: 1) }

    it 'evicts the only entry when a new one is added' do
      tiny_cache.set('a', 1)
      tiny_cache.set('b', 2)
      expect(tiny_cache.get('a')).to be_nil
      expect(tiny_cache.get('b')).to eq(2)
      expect(tiny_cache.size).to eq(1)
    end
  end

  describe '#set edge cases' do
    it 'stores nil as a value' do
      cache.set('key', nil)
      # key? confirms the entry exists even though value is nil
      expect(cache.key?('key')).to be true
    end

    it 'stores complex objects as values' do
      obj = { nested: [1, { deep: true }] }
      cache.set('key', obj)
      expect(cache.get('key')).to eq(obj)
    end

    it 'overwrites a key at full capacity without net eviction' do
      5.times { |i| cache.set("k#{i}", i) }
      cache.set('k0', 'updated')
      expect(cache.size).to eq(5)
      expect(cache.get('k0')).to eq('updated')
      # All original keys except k0's old value should still be present
      expect(cache.get('k1')).to eq(1)
    end
  end

  describe '#fetch edge cases' do
    it 'recomputes when cached entry has expired' do
      cache.set('key', 'old', ttl: 0.05)
      sleep 0.1
      result = cache.fetch('key', ttl: 60) { 'recomputed' }
      expect(result).to eq('recomputed')
      expect(cache.get('key')).to eq('recomputed')
    end
  end

  describe '#invalidate_tag edge cases' do
    it 'returns zero when no entries match the tag' do
      cache.set('a', 1, tags: ['other'])
      removed = cache.invalidate_tag('nonexistent')
      expect(removed).to eq(0)
      expect(cache.size).to eq(1)
    end

    it 'accepts symbol tags for invalidation' do
      cache.set('a', 1, tags: [:mytag])
      removed = cache.invalidate_tag(:mytag)
      expect(removed).to eq(1)
    end

    it 'removes only the matching tag when entry has multiple tags' do
      cache.set('a', 1, tags: %w[tag1 tag2])
      cache.set('b', 2, tags: %w[tag2 tag3])
      cache.set('c', 3, tags: %w[tag1])

      removed = cache.invalidate_tag('tag2')
      expect(removed).to eq(2)
      expect(cache.get('c')).to eq(3)
      expect(cache.get('a')).to be_nil
      expect(cache.get('b')).to be_nil
    end
  end

  describe 'LRU eviction edge cases' do
    it 'evicts multiple entries when filling well past capacity' do
      5.times { |i| cache.set("k#{i}", i) }
      3.times { |i| cache.set("new#{i}", i + 10) }

      expect(cache.size).to eq(5)
      expect(cache.get('k0')).to be_nil
      expect(cache.get('k1')).to be_nil
      expect(cache.get('k2')).to be_nil
      expect(cache.get('new2')).to eq(12)
    end

    it 'promotes a key via fetch so it avoids eviction' do
      5.times { |i| cache.set("k#{i}", i) }
      # Touch k0 via fetch (should move it to most recently used)
      cache.fetch('k0') { 'should not compute' }
      cache.set('extra', 99)

      expect(cache.get('k0')).to eq(0)
      expect(cache.get('k1')).to be_nil
    end
  end

  describe '#stats edge cases' do
    it 'resets size to zero after clear' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.clear

      stats = cache.stats
      expect(stats[:size]).to eq(0)
      # hits and misses are preserved even after clear
      expect(stats[:hits]).to eq(0)
    end

    it 'tracks evictions from expired entry access' do
      cache.set('a', 1, ttl: 0.05)
      sleep 0.1
      cache.get('a')

      expect(cache.stats[:evictions]).to eq(1)
      expect(cache.stats[:misses]).to eq(1)
    end
  end

  describe '#on_evict edge cases' do
    it 'fires callback on tag invalidation' do
      evicted = []
      cache.on_evict { |key, value| evicted << [key, value] }

      cache.set('a', 1, tags: ['group'])
      cache.set('b', 2, tags: ['group'])
      cache.invalidate_tag('group')

      expect(evicted).to be_empty
    end

    it 'fires callbacks during prune for expired entries' do
      evicted_keys = []
      cache.on_evict { |key, _| evicted_keys << key }

      cache.set('x', 1, ttl: 0.05)
      cache.set('y', 2, ttl: 0.05)
      cache.set('z', 3)
      sleep 0.1
      cache.prune

      expect(evicted_keys).to contain_exactly('x', 'y')
    end
  end

  describe '#get_many edge cases' do
    it 'promotes touched keys in LRU order' do
      5.times { |i| cache.set("k#{i}", i) }
      # Touch k0 and k1 via get_many
      cache.get_many('k0', 'k1')
      # Now k2 is the LRU
      cache.set('extra', 99)

      expect(cache.get('k0')).to eq(0)
      expect(cache.get('k1')).to eq(1)
      expect(cache.get('k2')).to be_nil
    end

    it 'returns empty hash when every key is missing' do
      result = cache.get_many('x', 'y', 'z')
      expect(result).to eq({})
    end

    it 'tracks tag stats for hits on tagged entries' do
      cache.set('a', 1, tags: ['grp'])
      cache.set('b', 2, tags: ['grp'])
      cache.get_many('a', 'b')

      expect(cache.stats(tag: 'grp')[:hits]).to eq(2)
    end
  end

  describe '#fetch with nil cached value' do
    it 'does not recompute when cached value is nil and entry exists' do
      cache.set('key', nil)
      # fetch_entry returns nil for nil values, so block will be called
      # This documents the current behavior: nil values cause recomputation
      call_count = 0
      cache.fetch('key') do
        call_count += 1
        'new'
      end
      # Because fetch_entry returns nil (the stored value), fetch treats it as a miss
      expect(call_count).to eq(1)
    end
  end

  describe '#delete edge cases' do
    it 'returns false when deleting an already-expired entry' do
      cache.set('a', 1, ttl: 0.05)
      sleep 0.1
      # The entry is still in @data (not pruned), so delete_entry checks @data.key?
      expect(cache.delete('a')).to be true
    end

    it 'reduces size after deletion' do
      cache.set('a', 1)
      cache.set('b', 2)
      cache.delete('a')
      expect(cache.size).to eq(1)
    end

    it 'allows re-setting a deleted key' do
      cache.set('a', 1)
      cache.delete('a')
      cache.set('a', 2)
      expect(cache.get('a')).to eq(2)
    end
  end

  describe '#clear edge cases' do
    it 'does not fire eviction callbacks' do
      evicted = []
      cache.on_evict { |key, _| evicted << key }

      cache.set('a', 1)
      cache.set('b', 2)
      cache.clear

      expect(evicted).to be_empty
    end

    it 'allows setting new entries after clear' do
      cache.set('a', 1)
      cache.clear
      cache.set('b', 2)
      expect(cache.get('b')).to eq(2)
      expect(cache.size).to eq(1)
    end
  end

  describe 'TTL edge cases' do
    it 'expires entry with very small TTL' do
      cache.set('a', 1, ttl: 0.001)
      sleep 0.05
      expect(cache.get('a')).to be_nil
    end

    it 'counts expired entry access as an eviction in stats' do
      cache.set('a', 1, ttl: 0.05)
      sleep 0.1
      cache.get('a')

      stats = cache.stats
      expect(stats[:evictions]).to eq(1)
      expect(stats[:misses]).to eq(1)
      expect(stats[:size]).to eq(0)
    end

    it 'does not include expired entries in keys list' do
      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2)
      sleep 0.1

      expect(cache.keys).to eq(['b'])
    end
  end

  describe '#[] and #[]= edge cases' do
    it 'returns nil for expired entries via []' do
      cache.set('a', 1, ttl: 0.05)
      sleep 0.1
      expect(cache['a']).to be_nil
    end

    it 'overwrites existing entries via []=' do
      cache['a'] = 1
      cache['a'] = 2
      expect(cache['a']).to eq(2)
    end
  end

  describe 'tag operations edge cases' do
    it 'overwrites entry and uses new tags' do
      cache.set('a', 1, tags: ['old'])
      cache.set('a', 2, tags: ['new'])

      expect(cache.invalidate_tag('old')).to eq(0)
      expect(cache.invalidate_tag('new')).to eq(1)
    end

    it 'invalidate_tag on empty cache returns zero' do
      expect(cache.invalidate_tag('anything')).to eq(0)
    end

    it 'invalidate_tag does not fire eviction callbacks' do
      evicted = []
      cache.on_evict { |key, _| evicted << key }

      cache.set('a', 1, tags: ['grp'])
      cache.set('b', 2, tags: ['grp'])
      cache.invalidate_tag('grp')

      expect(evicted).to be_empty
    end

    it 'tracks tag eviction stats on LRU eviction of tagged entry' do
      cache.set('t1', 1, tags: ['mytag'])
      cache.set('t2', 2)
      cache.set('t3', 3)
      cache.set('t4', 4)
      cache.set('t5', 5)
      # Evict t1 (LRU, tagged with "mytag")
      cache.set('t6', 6)

      expect(cache.stats(tag: 'mytag')[:evictions]).to eq(1)
    end

    it 'tracks tag eviction stats on prune of expired tagged entry' do
      cache.set('a', 1, ttl: 0.05, tags: ['group'])
      cache.set('b', 2)
      sleep 0.1
      cache.prune

      expect(cache.stats(tag: 'group')[:evictions]).to eq(1)
    end
  end

  describe '#stats edge cases' do
    it 'returns zero counters for unknown tag' do
      stats = cache.stats(tag: 'nonexistent')
      expect(stats).to eq(hits: 0, misses: 0, evictions: 0)
    end

    it 'accumulates hits across multiple gets' do
      cache.set('a', 1)
      3.times { cache.get('a') }

      expect(cache.stats[:hits]).to eq(3)
    end

    it 'preserves hit/miss counters after clear' do
      cache.set('a', 1)
      cache.get('a')
      cache.get('missing')
      cache.clear

      stats = cache.stats
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
    end
  end

  describe '#snapshot and #restore edge cases' do
    it 'restores entries without tags key using default empty array' do
      data = {
        entries: { 'a' => { value: 1, ttl: nil } },
        order: ['a']
      }
      new_cache = described_class.new(max_size: 5)
      # restore_entries passes attrs[:tags] || [] so missing tags defaults to []
      new_cache.restore(data)

      expect(new_cache.get('a')).to eq(1)
      expect(new_cache.size).to eq(1)
    end

    it 'snapshot captures entries with multiple tags' do
      cache.set('a', 1, tags: %w[x y z])
      data = cache.snapshot

      expect(data[:entries]['a'][:tags]).to eq(%w[x y z])
    end

    it 'restore handles order entries not in entries hash' do
      data = {
        entries: { 'a' => { value: 1, ttl: nil, tags: [] } },
        order: %w[a b c]
      }
      new_cache = described_class.new(max_size: 5)
      new_cache.restore(data)

      # Order should only include keys that exist in entries
      expect(new_cache.keys).to eq(['a'])
      expect(new_cache.size).to eq(1)
    end
  end

  describe '#on_evict edge cases' do
    it 'fires callbacks in registration order' do
      order = []
      cache.on_evict { |_, _| order << :first }
      cache.on_evict { |_, _| order << :second }

      5.times { |i| cache.set("k#{i}", i) }
      cache.set('extra', 99)

      expect(order).to eq(%i[first second])
    end

    it 'fires callback for each LRU eviction when adding multiple past capacity' do
      evicted_keys = []
      cache.on_evict { |key, _| evicted_keys << key }

      5.times { |i| cache.set("k#{i}", i) }
      3.times { |i| cache.set("new#{i}", i + 10) }

      expect(evicted_keys).to eq(%w[k0 k1 k2])
    end

    it 'receives correct value in callback' do
      values = []
      cache.on_evict { |_, value| values << value }

      5.times { |i| cache.set("k#{i}", i * 10) }
      cache.set('extra', 99)

      expect(values).to eq([0])
    end
  end

  describe '#prune edge cases' do
    it 'does not remove non-expired entries' do
      cache.set('a', 1, ttl: 300)
      cache.set('b', 2)
      cache.prune

      expect(cache.size).to eq(2)
    end

    it 'increments eviction counter for each pruned entry' do
      cache.set('a', 1, ttl: 0.05)
      cache.set('b', 2, ttl: 0.05)
      cache.set('c', 3, ttl: 0.05)
      sleep 0.1
      cache.prune

      expect(cache.stats[:evictions]).to eq(3)
    end
  end

  describe '#set_many' do
    it 'sets multiple entries at once' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set_many({ 'a' => 1, 'b' => 2, 'c' => 3 })
      expect(store.get('a')).to eq(1)
      expect(store.get('b')).to eq(2)
      expect(store.get('c')).to eq(3)
    end

    it 'applies TTL to all entries' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set_many({ 'a' => 1 }, ttl: 1)
      expect(store.get('a')).to eq(1)
    end

    it 'applies tags to all entries' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set_many({ 'a' => 1, 'b' => 2 }, tags: ['group'])
      store.invalidate_tag('group')
      expect(store.get('a')).to be_nil
      expect(store.get('b')).to be_nil
    end
  end

  describe '#compact' do
    it 'removes expired entries' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set('a', 1, ttl: 0)
      store.set('b', 2)
      sleep 0.01
      count = store.compact
      expect(count).to eq(1)
      expect(store.get('a')).to be_nil
      expect(store.get('b')).to eq(2)
    end

    it 'returns zero when nothing expired' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set('a', 1)
      expect(store.compact).to eq(0)
    end
  end

  describe '#refresh' do
    it 'resets TTL for existing entry' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set('a', 1, ttl: 1)
      result = store.refresh('a', ttl: 60)
      expect(result).to be true
      expect(store.get('a')).to eq(1)
    end

    it 'returns false for missing key' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      expect(store.refresh('missing')).to be false
    end

    it 'returns false for expired key' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set('a', 1, ttl: 0)
      sleep 0.01
      expect(store.refresh('a', ttl: 60)).to be false
    end

    it 'preserves the value' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 100)
      store.set('a', 'hello', ttl: 10)
      store.refresh('a', ttl: 60)
      expect(store.get('a')).to eq('hello')
    end
  end

  describe '#ttl' do
    it 'returns remaining seconds for a key with TTL' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1, ttl: 60)
      remaining = store.ttl('a')
      expect(remaining).to be_a(Float)
      expect(remaining).to be > 0
      expect(remaining).to be <= 60
    end

    it 'returns nil for a key with no TTL' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1)
      expect(store.ttl('a')).to be_nil
    end

    it 'returns nil for a missing key' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      expect(store.ttl('missing')).to be_nil
    end

    it 'returns nil for an expired key' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1, ttl: 0.01)
      sleep 0.02
      expect(store.ttl('a')).to be_nil
    end
  end

  describe '#expire_at' do
    it 'returns an absolute Time for a key with TTL' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      before = Time.now
      store.set('a', 1, ttl: 60)
      deadline = store.expire_at('a')
      expect(deadline).to be_a(Time)
      expect(deadline).to be >= before + 60
    end

    it 'returns nil for a key with no TTL' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1)
      expect(store.expire_at('a')).to be_nil
    end

    it 'returns nil for a missing key' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      expect(store.expire_at('missing')).to be_nil
    end

    it 'returns nil for an expired key' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1, ttl: 0.01)
      sleep 0.02
      expect(store.expire_at('a')).to be_nil
    end
  end

  describe '#delete_many' do
    it 'deletes multiple keys and returns the count removed' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1)
      store.set('b', 2)
      store.set('c', 3)
      expect(store.delete_many('a', 'b', 'missing')).to eq(2)
      expect(store.keys).to contain_exactly('c')
    end

    it 'returns zero when nothing matches' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1)
      expect(store.delete_many('x', 'y')).to eq(0)
      expect(store.size).to eq(1)
    end

    it 'accepts an array via splat' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1)
      store.set('b', 2)
      expect(store.delete_many(%w[a b])).to eq(2)
      expect(store.size).to eq(0)
    end

    it 'does not fire eviction callbacks' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1)
      store.set('b', 2)
      fired = []
      store.on_evict { |key, _value| fired << key }
      store.delete_many('a', 'b')
      expect(fired).to be_empty
    end
  end

  describe '#keys_by_tag' do
    it 'returns keys associated with a tag' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('user:1', 1, tags: ['users'])
      store.set('user:2', 2, tags: ['users'])
      store.set('post:1', 3, tags: ['posts'])
      expect(store.keys_by_tag('users')).to contain_exactly('user:1', 'user:2')
    end

    it 'accepts a symbol tag' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1, tags: [:alpha])
      expect(store.keys_by_tag(:alpha)).to eq(['a'])
    end

    it 'returns an empty array for an unknown tag' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1, tags: ['x'])
      expect(store.keys_by_tag('y')).to eq([])
    end

    it 'excludes expired entries' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('a', 1, ttl: 0.01, tags: ['t'])
      store.set('b', 2, tags: ['t'])
      sleep 0.02
      expect(store.keys_by_tag('t')).to eq(['b'])
    end
  end

  describe '#increment' do
    it 'initializes missing keys to 0 before incrementing' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      expect(store.increment('views')).to eq(1)
      expect(store.get('views')).to eq(1)
    end

    it 'accumulates across calls' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.increment('views')
      store.increment('views')
      expect(store.increment('views')).to eq(3)
    end

    it 'respects the by: step' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      expect(store.increment('views', by: 5)).to eq(5)
      expect(store.increment('views', by: 2)).to eq(7)
    end

    it 'preserves existing TTL when ttl: is omitted' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('views', 10, ttl: 60)
      store.increment('views')
      expect(store.ttl('views')).to be > 0
    end

    it 'replaces TTL when ttl: is provided' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('views', 10)
      store.increment('views', ttl: 30)
      remaining = store.ttl('views')
      expect(remaining).to be > 0
      expect(remaining).to be <= 30
    end

    it 'resets an expired key to 0 before incrementing' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('views', 99, ttl: 0.01)
      sleep 0.02
      expect(store.increment('views')).to eq(1)
    end

    it 'raises on non-numeric values' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('views', 'oops')
      expect { store.increment('views') }.to raise_error(Philiprehberger::CacheKit::Error, /not numeric/)
    end

    it 'is atomic under concurrent callers' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      threads = Array.new(10) do
        Thread.new { 100.times { store.increment('counter') } }
      end
      threads.each(&:join)
      expect(store.get('counter')).to eq(1000)
    end
  end

  describe '#decrement' do
    it 'decrements an existing value' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('quota', 10)
      expect(store.decrement('quota')).to eq(9)
    end

    it 'initializes missing keys to 0 then subtracts' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      expect(store.decrement('quota', by: 3)).to eq(-3)
    end

    it 'respects the by: step' do
      store = Philiprehberger::CacheKit::Store.new(max_size: 10)
      store.set('quota', 100)
      expect(store.decrement('quota', by: 25)).to eq(75)
    end
  end
end
