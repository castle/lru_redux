class LruRedux::TTL::ThreadSafeCache < LruRedux::TTL::Cache
  include LruRedux::Util::SafeSync

  # #expire is TTL cache only, so it is not part of SafeSync
  def expire
    synchronize do
      super
    end
  end
end
