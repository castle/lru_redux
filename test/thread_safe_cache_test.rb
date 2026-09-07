require './test/cache_test'

class ThreadSafeCacheTest < CacheTest
  def setup
    @c = LruRedux::ThreadSafeCache.new(3)
  end

  def new_cache(max_size, options = {})
    LruRedux::ThreadSafeCache.new(max_size, options)
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
