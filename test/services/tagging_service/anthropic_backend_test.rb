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

  def propose_with(body, name = names(:bacillus))
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

  def text_body(json, stop_reason: 'end_turn', usage: nil)
    { 'stop_reason' => stop_reason,
      'content' => [{ 'type' => 'text', 'text' => JSON.generate(json) }],
      'usage' => usage }.compact
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

  test 'prompt passes the genus gender for species only' do
    prompt = lambda do |name|
      _, requests = propose_with(text_body({ 'tags' => [] }), name)
      JSON.parse(requests.first.body).dig('messages', 0, 'content')
    end

    assert_no_match(/^Genus gender:/, prompt[names(:escherichia)])
    assert_match(
      /^Genus gender: not recorded; infer it from the genus name Escherichia$/,
      prompt[names(:escherichia_coli)]
    )

    names(:escherichia).update_column(:etymology_xx_grammar, 'fem. n.')
    assert_match(
      /^Genus gender: feminine \(declared in the etymology of Escherichia\)$/,
      prompt[Name.find(names(:escherichia_coli).id)]
    )
  end

  test 'system prompt is identical for different names and cached' do
    requests = [names(:escherichia), names(:escherichia_coli)].map do |name|
      _, sent = propose_with(text_body({ 'tags' => [] }), name)
      JSON.parse(sent.first.body)
    end

    systems = requests.map { |body| body['system'] }
    assert_equal(systems.first, systems.last)
    assert_equal({ 'type' => 'ephemeral' }, systems.first.last['cache_control'])
    system_text = systems.first.map { |block| block['text'] }.join
    assert_no_match(/Escherichia|Etymology:/, system_text)

    contents = requests.map { |body| body.dig('messages', 0, 'content') }
    assert_match(/^Name: Escherichia$/, contents.first)
    assert_match(/^Name: Escherichia coli$/, contents.last)
  end

  test 'propose totals the token usage' do
    TaggingService.reset_usage
    usage = {
      'input_tokens' => 30, 'cache_creation_input_tokens' => 0,
      'cache_read_input_tokens' => 2000, 'output_tokens' => 50
    }
    2.times { propose_with(text_body({ 'tags' => [] }, usage: usage)) }

    assert_equal(
      { 'requests' => 2, 'input_tokens' => 60,
        'cache_creation_input_tokens' => 0,
        'cache_read_input_tokens' => 4000, 'output_tokens' => 100 },
      TaggingService.usage
    )
    assert_match(
      'cache_read_input_tokens 4000', TaggingService.usage_summary
    )
  end
end
