# Ruby 1.9 makes our life easier, Hash is already ordered
#
# This is an ultra efficient 1.9 freindly implementation
class LruRedux::Cache
  def getset(key)
    found = true
    value = @data.delete(key){ found = false }
    if found
      @data[key] = value
    else
      result = @data[key] = yield
      evict_lru if @data.length > @max_size
      result
    end
  end

  def []=(key,val)
    @data.delete(key)
    @data[key] = val
    evict_lru if @data.length > @max_size
    val
  end

  protected

  # Hash#shift is broken before Ruby 2.1, so the least recently used entry is
  # looked up and deleted by key instead.
  # this may seem odd see: http://bugs.ruby-lang.org/issues/8312
  def evict_lru
    while @data.size > @max_size
      key = @data.first[0]
      value = @data.delete(key)

      @on_evict.call(key, value) if @on_evict
    end
  end
end
