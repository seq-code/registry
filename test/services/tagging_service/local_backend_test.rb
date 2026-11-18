require 'test_helper'
require 'minitest/mock'

class TaggingService::LocalBackendTest < ActiveSupport::TestCase
  def fake_http(body, requests, code: '200', raises: nil)
    klass = code == '200' ? Net::HTTPOK : Net::HTTPInternalServerError
    response = klass.new('1.1', code, '').tap do |res|
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, JSON.generate(body))
    end
    Object.new.tap do |http|
      http.define_singleton_method(:use_ssl=) { |_| }
      http.define_singleton_method(:open_timeout=) { |_| }
      http.define_singleton_method(:read_timeout=) { |_| }
      http.define_singleton_method(:request) do |req|
        requests << req
        raise raises if raises

        response
      end
    end
  end

  def propose_with(
    body, name = names(:bacillus), code: '200', raises: nil,
    backend: TaggingService::LocalBackend.new
  )
    name.etymology_xx_description = 'a small rod'
    requests = []
    result = nil
    http = fake_http(body, requests, code: code, raises: raises)
    Net::HTTP.stub(:new, http) do
      result = backend.propose(name)
    end
    [result, requests]
  end

  def chat_body(json, finish_reason: 'stop', usage: nil)
    { 'choices' => [{ 'finish_reason' => finish_reason,
                      'message' => { 'role' => 'assistant',
                                     'content' => JSON.generate(json) } }],
      'usage' => usage }.compact
  end

  test 'propose sends the shared prompt to the local endpoint' do
    _, requests = propose_with(chat_body({ 'tags' => [] }))
    req = requests.first
    body = JSON.parse(req.body)

    assert_equal('/v1/chat/completions', req.path)
    assert_equal(%w[system user], body['messages'].map { |m| m['role'] })
    assert_equal(
      TaggingService::LocalBackend.new.system_prompt,
      body.dig('messages', 0, 'content')
    )
    assert_match(/^Name: Bacillus$/, body.dig('messages', 1, 'content'))
  end

  test 'propose ignores bypass_external_apis' do
    assert(Rails.configuration.bypass_external_apis)
    result, = propose_with(chat_body({ 'tags' => [] }))
    assert_equal([], result)
  end

  test 'propose requests structured output constrained to known slugs' do
    _, requests = propose_with(chat_body({ 'tags' => [] }))

    format = JSON.parse(requests.first.body)['response_format']
    assert_equal('json_schema', format['type'])
    slugs = format.dig(
      'json_schema', 'schema', 'properties', 'tags', 'items', 'properties',
      'slug', 'enum'
    )
    assert_equal(Tag.order(:slug).pluck(:slug), slugs)
  end

  test 'propose returns proposals from the structured response' do
    result, = propose_with(
      chat_body({ 'tags' => [
        { 'slug' => 'eponym', 'confidence' => 'high' },
        { 'slug' => 'not-a-tag', 'confidence' => 'low' }
      ] })
    )
    assert_equal([{ 'slug' => 'eponym', 'confidence' => 'high' }], result)
  end

  test 'propose raises on truncated output' do
    error = assert_raises(TaggingService::Error) do
      propose_with(chat_body({ 'tags' => [] }, finish_reason: 'length'))
    end
    assert_match('truncated', error.message)
  end

  test 'propose raises on server errors' do
    error = assert_raises(TaggingService::Error) do
      propose_with({ 'error' => 'boom' }, code: '500')
    end
    assert_match('Local model error 500', error.message)
  end

  test 'propose raises on responses of unexpected shape' do
    [[], { 'tags' => 'eponym' }, 'eponym'].each do |json|
      error = assert_raises(TaggingService::Error) do
        propose_with(chat_body(json))
      end
      assert_match('Unexpected model response', error.message)
    end

    error = assert_raises(TaggingService::Error) { propose_with([]) }
    assert_match('no choices', error.message)
  end

  test 'propose ignores tag entries that are not objects' do
    result, = propose_with(
      chat_body({ 'tags' => ['eponym', { 'slug' => 'eponym',
                                         'confidence' => 'high' }] })
    )
    assert_equal([{ 'slug' => 'eponym', 'confidence' => 'high' }], result)
  end

  test 'propose sends max_tokens from local_max_tokens, or the default' do
    _, requests = propose_with(chat_body({ 'tags' => [] }))
    assert_equal(
      TaggingService::LocalBackend::DEFAULT_MAX_TOKENS,
      JSON.parse(requests.first.body)['max_tokens']
    )

    backend = TaggingService::LocalBackend.new
    settings = ->(key) { key == :local_max_tokens ? '4096' : nil }
    backend.stub(:setting, settings) do
      _, requests = propose_with(chat_body({ 'tags' => [] }), backend: backend)
    end
    assert_equal(4096, JSON.parse(requests.first.body)['max_tokens'])
  end

  test 'propose maps connection and SSL errors to TaggingService::Error' do
    [Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].each do |klass|
      error = assert_raises(TaggingService::Error) do
        propose_with(chat_body({ 'tags' => [] }), raises: klass)
      end
      assert_match('Local model connection error', error.message)
    end
  end

  test 'propose keeps the path prefix of local_url' do
    backend = TaggingService::LocalBackend.new
    settings = ->(key) { key == :local_url ? 'http://gpu:8080/llama' : nil }
    requests = nil
    backend.stub(:setting, settings) do
      _, requests = propose_with(chat_body({ 'tags' => [] }), backend: backend)
    end
    assert_equal('/llama/v1/chat/completions', requests.first.path)
  end

  test 'propose uses the default URL without a path prefix' do
    _, requests = propose_with(chat_body({ 'tags' => [] }))
    assert_equal('/v1/chat/completions', requests.first.path)
  end

  test 'propose totals the token usage, separating cached prompt tokens' do
    TaggingService.reset_usage
    usage = {
      'prompt_tokens' => 2030, 'completion_tokens' => 50,
      'prompt_tokens_details' => { 'cached_tokens' => 2000 }
    }
    2.times { propose_with(chat_body({ 'tags' => [] }, usage: usage)) }

    assert_equal(
      { 'requests' => 2, 'input_tokens' => 60,
        'cache_creation_input_tokens' => 0,
        'cache_read_input_tokens' => 4000, 'output_tokens' => 100 },
      TaggingService.usage
    )
  end

  test 'model_label reports the served model, or unknown' do
    requests = []
    body = { 'data' => [{ 'id' => 'olmo-3-7b-instruct-q8_0.gguf' }] }
    Net::HTTP.stub(:new, fake_http(body, requests)) do
      assert_equal(
        'olmo-3-7b-instruct-q8_0.gguf',
        TaggingService::LocalBackend.model_label
      )
    end
    assert_equal('/v1/models', requests.first.path)

    Net::HTTP.stub(:new, ->(*) { raise Errno::ECONNREFUSED }) do
      assert_equal('unknown', TaggingService::LocalBackend.model_label)
    end
  end
end
