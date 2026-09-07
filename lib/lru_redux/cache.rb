# Ruby 1.9 makes our life easier, Hash is already ordered
#
# This is an ultra efficient 1.9 freindly implementation
class LruRedux::Cache
  attr_reader :max_size, :on_evict

  def initialize(*args)
    max_size, ttl, options = args

    if ttl.is_a?(Hash) && options.nil?
      options = ttl
    end

    options ||= {}

    raise ArgumentError.new(:max_size) if max_size < 1

    @max_size = max_size
    @on_evict = validate_on_evict(options[:on_evict])
    @data = {}
  end

  def max_size=(max_size)
    max_size ||= @max_size

    raise ArgumentError.new(:max_size) if max_size < 1

    @max_size = max_size

    evict_lru
  end

  def ttl=(_)
    nil
  end

  # Takes a callable accepting (key, value) or nil to disable the callback.
  def on_evict=(on_evict)
    @on_evict = validate_on_evict(on_evict)
  end

  def getset(key)
    found = true
    value = @data.delete(key){ found = false }
    if found
      @data[key] = value
    else
      result = @data[key] = yield
      # the callback free path stays inline to keep #getset as fast as it
      # was before on_evict was introduced
      if @data.length > @max_size
        @on_evict ? evict_lru : @data.shift
      end
      result
    end
  end

  def fetch(key)
    found = true
    value = @data.delete(key){ found = false }
    if found
      @data[key] = value
    else
      yield if block_given?
    end
  end

  def [](key)
    found = true
    value = @data.delete(key){ found = false }
    if found
      @data[key] = value
    else
      nil
    end
  end

  def []=(key,val)
    @data.delete(key)
    @data[key] = val
    if @data.length > @max_size
      @on_evict ? evict_lru : @data.shift
    end
    val
  end

  def each
    array = @data.to_a
    array.reverse!.each do |pair|
      yield pair
    end
  end

  # used further up the chain, non thread safe each
  alias_method :each_unsafe, :each

  def to_a
    array = @data.to_a
    array.reverse!
  end

  def values
    vals = @data.values
    vals.reverse!
  end

  def delete(key)
    @data.delete(key)
  end

  alias_method :evict, :delete

  def key?(key)
    @data.key?(key)
  end

  alias_method :has_key?, :key?

  def clear
    # the cache is emptied before the first callback runs so that a callback
    # calling back into the cache does not have its entry cleared
    data = @data
    @data = {}

    if @on_evict
      data.each do |key, value|
        @on_evict.call(key, value)
      end
    end

    data.clear
  end

  def count
    @data.size
  end

  protected

  # for cache validation only, ensures all is sound
  def valid?
    true
  end

  def validate_on_evict(on_evict)
    raise ArgumentError.new(:on_evict) unless
        on_evict.nil? || on_evict.respond_to?(:call)

    on_evict
  end

  # Drops the least recently used entries until the cache is back within
  # max_size, notifying the on_evict callback of every dropped entry.  The
  # entry is removed before the callback runs, so a callback is free to call
  # back into the cache.
  def evict_lru
    while @data.size > @max_size
      key, value = @data.shift

      @on_evict.call(key, value) if @on_evict
    end
  end
end
