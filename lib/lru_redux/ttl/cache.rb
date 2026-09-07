module LruRedux
  module TTL
    class Cache
      attr_reader :max_size, :ttl, :on_evict

      def initialize(*args)
        max_size, ttl, options = args

        if ttl.is_a?(Hash) && options.nil?
          options = ttl
          ttl = nil
        end

        options ||= {}
        ttl ||= :none

        raise ArgumentError.new(:max_size) if
            max_size < 1
        raise ArgumentError.new(:ttl) unless
            ttl == :none || ((ttl.is_a? Numeric) && ttl >= 0)

        @max_size = max_size
        @ttl = ttl
        @on_evict = validate_on_evict(options[:on_evict])
        @data_lru = {}
        @data_ttl = {}
      end

      def max_size=(max_size)
        max_size ||= @max_size

        raise ArgumentError.new(:max_size) if
            max_size < 1

        @max_size = max_size

        resize
      end

      def ttl=(ttl)
        ttl ||= @ttl

        raise ArgumentError.new(:ttl) unless
            ttl == :none || ((ttl.is_a? Numeric) && ttl >= 0)

        @ttl = ttl

        ttl_evict
      end

      # Takes a callable accepting (key, value) or nil to disable the callback.
      def on_evict=(on_evict)
        @on_evict = validate_on_evict(on_evict)
      end

      def getset(key)
        ttl_evict

        found = true
        value = @data_lru.delete(key){ found = false }
        if found
          @data_lru[key] = value
        else
          result = @data_lru[key] = yield
          @data_ttl[key] = Time.now.to_f

          evict_lru

          result
        end
      end

      def fetch(key)
        ttl_evict

        found = true
        value = @data_lru.delete(key){ found = false }
        if found
          @data_lru[key] = value
        else
          yield if block_given?
        end
      end

      def [](key)
        ttl_evict

        found = true
        value = @data_lru.delete(key){ found = false }
        if found
          @data_lru[key] = value
        else
          nil
        end
      end

      def []=(key, val)
        ttl_evict

        @data_lru.delete(key)
        @data_ttl.delete(key)

        @data_lru[key] = val
        @data_ttl[key] = Time.now.to_f

        evict_lru

        val
      end

      def each
        ttl_evict

        array = @data_lru.to_a
        array.reverse!.each do |pair|
          yield pair
        end
      end

      # used further up the chain, non thread safe each
      alias_method :each_unsafe, :each

      def to_a
        ttl_evict

        array = @data_lru.to_a
        array.reverse!
      end

      def values
        ttl_evict

        vals = @data_lru.values
        vals.reverse!
      end

      def delete(key)
        ttl_evict

        @data_lru.delete(key)
        @data_ttl.delete(key)
      end

      alias_method :evict, :delete

      def key?(key)
        ttl_evict

        @data_lru.key?(key)
      end

      alias_method :has_key?, :key?

      def clear
        # the cache is emptied before the first callback runs so that a
        # callback calling back into the cache does not have its entry cleared
        data_lru = @data_lru
        @data_lru = {}
        @data_ttl = {}

        if @on_evict
          data_lru.each do |key, value|
            @on_evict.call(key, value)
          end
        end

        data_lru.clear
      end

      def expire
        ttl_evict
      end

      def count
        @data_lru.size
      end

      protected

      # for cache validation only, ensures all is sound
      def valid?
        @data_lru.size == @data_ttl.size
      end

      def validate_on_evict(on_evict)
        raise ArgumentError.new(:on_evict) unless
            on_evict.nil? || on_evict.respond_to?(:call)

        on_evict
      end

      def ttl_evict
        return if @ttl == :none

        ttl_horizon = Time.now.to_f - @ttl
        key, time = @data_ttl.first

        until time.nil? || time > ttl_horizon
          @data_ttl.delete(key)
          value = @data_lru.delete(key)

          @on_evict.call(key, value) if @on_evict

          key, time = @data_ttl.first
        end
      end

      # Drops the least recently used entries until the cache is back within
      # max_size, notifying the on_evict callback of every dropped entry.  The
      # entry is removed before the callback runs, so a callback is free to
      # call back into the cache.
      def evict_lru
        while @data_lru.size > @max_size
          key, value = @data_lru.first

          @data_lru.delete(key)
          @data_ttl.delete(key)

          @on_evict.call(key, value) if @on_evict
        end
      end

      def resize
        ttl_evict

        evict_lru
      end
    end
  end
end
