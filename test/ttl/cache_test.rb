require 'timecop'
require './test/cache_test'

class TTLCacheTest < CacheTest
  def setup
    Timecop.freeze(Time.now)
    @c = LruRedux::TTL::Cache.new 3, 5 * 60
  end

  def teardown
    Timecop.return
    assert_equal true, @c.send(:valid?)
  end

  def new_cache(max_size, options = {})
    new_ttl_cache(max_size, :none, options)
  end

  # Overridden by the TTL thread safe cache tests.
  def new_ttl_cache(max_size, ttl, options = {})
    LruRedux::TTL::Cache.new(max_size, ttl, options)
  end

  def test_ttl
    assert_equal 300, @c.ttl

    @c.ttl = 10 * 60

    assert_equal 600, @c.ttl
  end

  # TTL tests using Timecop
  def test_ttl_eviction_on_access
    @c[:a] = 1
    @c[:b] = 2

    Timecop.freeze(Time.now + 330)

    @c[:c] = 3

    assert_equal([[:c, 3]], @c.to_a)
  end

  def test_ttl_eviction_on_expire
    @c[:a] = 1
    @c[:b] = 2

    Timecop.freeze(Time.now + 330)

    @c.expire

    assert_equal([], @c.to_a)
  end

  def test_ttl_eviction_on_new_max_size
    @c[:a] = 1
    @c[:b] = 2

    Timecop.freeze(Time.now + 330)

    @c.max_size = 10

    assert_equal([], @c.to_a)
  end

  def test_ttl_eviction_on_new_ttl
    @c[:a] = 1
    @c[:b] = 2

    Timecop.freeze(Time.now + 330)

    @c.ttl = 10 * 60

    assert_equal([[:b, 2], [:a, 1]], @c.to_a)

    @c.ttl = 2 * 60

    assert_equal([], @c.to_a)
  end

  def test_ttl_precedence_over_lru
    @c[:a] = 1

    Timecop.freeze(Time.now + 60)

    @c[:b] = 2
    @c[:c] = 3

    @c[:a]

    assert_equal [[:a, 1], [:c, 3], [:b, 2]],
                 @c.to_a

    Timecop.freeze(Time.now + 270)

    @c[:d] = 4

    assert_equal [[:d, 4], [:c, 3], [:b, 2]],
                 @c.to_a
  end

  def test_on_evict_on_ttl_eviction
    evicted = []
    c = new_ttl_cache(3, 5 * 60, on_evict: lambda { |key, value| evicted << [key, value] })

    c[:a] = 1
    c[:b] = 2

    Timecop.freeze(Time.now + 330)

    c.expire

    assert_equal [[:a, 1], [:b, 2]], evicted
    assert_equal [], c.to_a
  end

  def test_on_evict_on_ttl_eviction_triggered_by_new_ttl
    evicted = []
    c = new_ttl_cache(3, 10 * 60, on_evict: lambda { |key, value| evicted << [key, value] })

    c[:a] = 1
    c[:b] = 2

    Timecop.freeze(Time.now + 330)

    c.ttl = 2 * 60

    assert_equal [[:a, 1], [:b, 2]], evicted
  end
end
