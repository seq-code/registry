require 'test_helper'
require 'minitest/mock'

class TaggingService::AnthropicBackendTest < ActiveSupport::TestCase
  def fake_http(body, requests)
    response = Net::HTTPOK.new('1.1', '200', '').tap do |res|
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, JSON.generate(body))
    end
    Object.new.tap do |http|
      http.define_singleton_method(:use_ssl=) { |_| }
      http.define_singleton_method(:open_timeout=) { |_| }
      http.define_singleton_method(:read_timeout=) { |_| }
      http.define_singleton_method(:request) { |req| requests << req; response }
    end
  end

  def propose_with(body)
    name = names(:bacillus)
    name.etymology_xx_description = 'a small rod'
    requests = []
    backend = TaggingService::AnthropicBackend.new
    result = nil
    Rails.configuration.stub(:bypass_external_apis, false) do
      Net::HTTP.stub(:new, fake_http(body, requests)) do
        backend.stub(:api_key, 'test-key') do
          result = backend.propose(name)
        end
      end
    end
    [result, requests]
  end

  def text_body(json, stop_reason: 'end_turn')
    { 'stop_reason' => stop_reason,
      'content' => [{ 'type' => 'text', 'text' => JSON.generate(json) }] }
  end

  test 'propose makes no request when external APIs are bypassed' do
    name = names(:bacillus)
    name.etymology_xx_description = 'a small rod'
    no_request = ->(*) { flunk('Unexpected request to the Anthropic API') }

    assert(Rails.configuration.bypass_external_apis)
    Net::HTTP.stub(:new, no_request) do
      error = assert_raises(TaggingService::Error) do
        TaggingService::AnthropicBackend.new.propose(name)
      end
      assert_match('External APIs are disabled', error.message)
    end
  end

  test 'propose requests structured output constrained to known slugs' do
    _, requests = propose_with(text_body({ 'tags' => [] }))

    format = JSON.parse(requests.first.body).dig('output_config', 'format')
    assert_equal('json_schema', format['type'])
    slugs = format.dig(
      'schema', 'properties', 'tags', 'items', 'properties', 'slug', 'enum'
    )
    assert_equal(Tag.order(:slug).pluck(:slug), slugs)
  end

  test 'propose returns proposals from the structured response' do
    result, = propose_with(
      text_body({ 'tags' => [
        { 'slug' => 'eponym', 'confidence' => 'high' },
        { 'slug' => 'not-a-tag', 'confidence' => 'low' }
      ] })
    )
    assert_equal([{ 'slug' => 'eponym', 'confidence' => 'high' }], result)
  end

  test 'propose raises on refusal' do
    error = assert_raises(TaggingService::Error) do
      propose_with('stop_reason' => 'refusal', 'content' => [])
    end
    assert_match('declined', error.message)
  end

  test 'propose raises on truncated output' do
    error = assert_raises(TaggingService::Error) do
      propose_with(text_body({ 'tags' => [] }, stop_reason: 'max_tokens'))
    end
    assert_match('truncated', error.message)
  end
end
