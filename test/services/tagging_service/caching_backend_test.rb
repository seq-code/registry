require 'test_helper'

class TaggingService::CachingBackendTest < ActiveSupport::TestCase
  # A backend that counts its calls and returns fixed proposals
  def counting_backend(calls)
    Class.new do
      define_singleton_method(:model_label) { 'fake-model' }
      define_method(:propose) do |_name|
        calls << 1
        [{ 'slug' => 'eponym', 'confidence' => 'high', 'basis' => 'X' }]
      end
    end
  end

  def with_cache_dir
    Dir.mktmpdir do |dir|
      ENV['TAGGING_CACHE'] = dir
      yield dir
    ensure
      ENV.delete('TAGGING_CACHE')
    end
  end

  test 'wrap returns the backend unchanged without TAGGING_CACHE' do
    backend = counting_backend([])
    assert_same(backend, TaggingService::CachingBackend.wrap(backend))
  end

  test 'records the first answer and replays it without calling the backend' do
    name = names(:bacillus)
    name.etymology_xx_description = 'a small rod'
    calls = []
    with_cache_dir do |dir|
      cached = TaggingService::CachingBackend.wrap(counting_backend(calls))
      first = cached.new.propose(name)
      second = cached.new.propose(name)

      assert_equal(1, calls.size)
      assert_equal(first, second)
      assert_equal(1, Dir.glob(File.join(dir, '*.json')).size)
      assert_match(/\Afake-model \(cache: /, cached.model_label)
    end
  end

  test 'a different prompt is a cache miss' do
    name = names(:bacillus)
    calls = []
    with_cache_dir do
      cached = TaggingService::CachingBackend.wrap(counting_backend(calls))
      name.etymology_xx_description = 'a small rod'
      cached.new.propose(name)
      name.etymology_xx_description = 'a large rod'
      cached.new.propose(name)

      assert_equal(2, calls.size)
    end
  end

  test 'model_label falls back when the backend is unavailable' do
    backend = Class.new do
      define_singleton_method(:model_label) { raise TaggingService::Error, 'down' }
    end
    with_cache_dir do
      label = TaggingService::CachingBackend.wrap(backend).model_label
      assert_match(/\Abackend unavailable, replay only \(cache: /, label)
    end
  end
end
