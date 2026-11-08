require 'test_helper'
require 'minitest/mock'

class DictionaryControllerTest < ActionDispatch::IntegrationTest
  XMLMORPH = { lang: 'la', lookup: 'rarus' }.freeze
  LOADQUERY = { doc: 'Perseus:text:1999.04.0059:entry=rarus' }.freeze

  def perseus_response(klass, code, body)
    klass.new('1.1', code, '').tap do |res|
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, body)
    end
  end

  # Run the block with Perseus answering +response+ (or raising it, if an
  # exception class), a working cache, and external APIs enabled. Returns
  # the number of requests sent to Perseus
  def with_perseus(response)
    calls = 0
    start = lambda do |*_args, **_opts|
      calls += 1
      raise(response) if response.is_a?(Class)

      response
    end
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      Rails.configuration.stub(:bypass_external_apis, false) do
        Net::HTTP.stub(:start, start) { yield }
      end
    end
    calls
  end

  test 'rejects unexpected services, parameters, and values' do
    ok = perseus_response(Net::HTTPOK, '200', '<analyses/>')
    calls = with_perseus(ok) do
      [
        ['xmlmorph', XMLMORPH.merge(lookup: 'two words')],
        ['xmlmorph', XMLMORPH.merge(lookup: 'rarus&x=1')],
        ['xmlmorph', XMLMORPH.merge(lang: 'greek')],
        ['xmlmorph', XMLMORPH.merge(extra: '1')],
        ['xmlmorph', { lookup: 'rarus' }],
        ['loadquery', { doc: 'Perseus:text:1999.02.0001:entry=rarus' }],
        ['loadquery', { doc: 'http://example.com/' }]
      ].each do |service, params|
        get(dictionary_url(service), params: params, xhr: true)
        assert_response(:bad_request, params.inspect)
      end

      # Only from the page's scripts
      get(dictionary_url('xmlmorph'), params: XMLMORPH)
      assert_response(:bad_request)
    end

    assert_equal(0, calls)
    assert_raises(ActionController::UrlGenerationError) do
      dictionary_url('search')
    end
  end

  test 'proxies and caches lookups' do
    ok = perseus_response(Net::HTTPOK, '200', '<analyses>rarus</analyses>')
    calls = with_perseus(ok) do
      2.times do
        get(dictionary_url('xmlmorph'), params: XMLMORPH, xhr: true)
        assert_response(:success)
        assert_equal('<analyses>rarus</analyses>', response.body)
        assert_equal('text/plain', response.media_type)
      end
    end

    assert_equal(1, calls)
  end

  test 'reports missing dictionary entries and caches them' do
    missing = perseus_response(Net::HTTPInternalServerError, '500', 'Error')
    calls = with_perseus(missing) do
      2.times do
        get(dictionary_url('loadquery'), params: LOADQUERY, xhr: true)
        assert_response(:not_found)
        assert_equal('Term not found', response.parsed_body['error'])
      end
    end

    assert_equal(1, calls)
  end

  test 'reports refusals without caching them' do
    refused = perseus_response(Net::HTTPMethodNotAllowed, '405', 'No')
    calls = with_perseus(refused) do
      2.times do
        get(dictionary_url('xmlmorph'), params: XMLMORPH, xhr: true)
        assert_response(:bad_gateway)
        assert_match('refused the request (HTTP 405)',
                     response.parsed_body['error'])
      end
    end

    assert_equal(2, calls)
  end

  test 'reports timeouts' do
    with_perseus(Net::ReadTimeout) do
      get(dictionary_url('loadquery'), params: LOADQUERY, xhr: true)
    end

    assert_response(:bad_gateway)
    assert_match('did not respond in time', response.parsed_body['error'])
  end

  test 'makes no requests when external APIs are disabled' do
    no_request = ->(*) { flunk('Unexpected request to Perseus') }
    Net::HTTP.stub(:start, no_request) do
      get(dictionary_url('xmlmorph'), params: XMLMORPH, xhr: true)
    end

    assert_response(:bad_gateway)
    assert_equal('External APIs are disabled', response.parsed_body['error'])
  end
end
