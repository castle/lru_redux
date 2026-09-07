require './test/ttl/cache_test'

class TTLThreadSafeCacheTest < TTLCacheTest
  def setup
    Timecop.freeze(Time.now)
    @c = LruRedux::TTL::ThreadSafeCache.new 3, 5 * 60
  end

  def new_ttl_cache(max_size, ttl, options = {})
    LruRedux::TTL::ThreadSafeCache.new(max_size, ttl, options)
  end

  def test_expire_holds_the_lock
    locked = []
    c = new_ttl_cache(3, 5 * 60, on_evict: lambda { |_key, _value| locked << c.send(:mon_owned?) })

    c[:a] = 1
    c[:b] = 2

    Timecop.freeze(Time.now + 330)

    c.expire

    assert_equal [true, true], locked
  end

  def test_concurrent_expire_and_writes
    evicted = Queue.new
    c = new_ttl_cache(100, 0.01, on_evict: lambda { |key, value| evicted << [key, value] })

    threads = 4.times.map do |t|
      Thread.new do
        500.times do |i|
          c["#{t}-#{i}"] = i
          c.expire
        end
      end
    end
    threads.each(&:join)

    assert_equal true, c.send(:valid?)
    refute_equal 0, evicted.size
    until evicted.empty?
      key, value = evicted.pop
      refute_nil key
      refute_nil value
    end
  end

  def test_recursion
    @c[:a] = 1
    @c[:b] = 2

    # should not blow up
    @c.each do |k, _|
      @c[k]
    end
  end
end