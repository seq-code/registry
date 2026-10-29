require 'test_helper'
require 'minitest/mock'

class Name::WikiTest < ActiveSupport::TestCase
  setup do
    @name = names(:escherichia_coli)
    @requests = []
  end

  def response(klass, code, body: '', headers: {})
    klass.new('1.1', code, '').tap do |res|
      res.instance_variable_set(:@read, true)
      res.instance_variable_set(:@body, body)
      headers.each { |key, value| res[key] = value }
    end
  end

  # Respond to every request of +@name+ with +res+, recording the URLs
  def stub_responses(res)
    requests = @requests
    @name.define_singleton_method(:external_response) do |uri|
      requests << uri
      res
    end
  end

  def with_cache(&blk)
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new, &blk)
  end

  test 'check_wikispecies records missing pages' do
    stub_responses(response(Net::HTTPNotFound, '404'))

    with_cache { @name.check_wikispecies }

    assert_includes(@name.wikispecies_issues_text, 'missing page')
    assert_predicate(@name, :wikispecies_checked_recently?)
  end

  test 'check_wikispecies does not report existing pages as missing' do
    stub_responses(response(Net::HTTPOK, '200', body: '<html></html>'))

    with_cache { @name.check_wikispecies }

    assert_not_includes(@name.wikispecies_issues, 'missing page')
    assert_predicate(@name, :wikispecies_checked_recently?)
  end

  test 'check_wikispecies keeps previous results and pauses when throttled' do
    @name.update_columns(
      wikispecies_issues_text: nil, wikispecies_checked_at: 1.year.ago
    )
    stub_responses(
      response(
        Net::HTTPTooManyRequests, '429', headers: { 'Retry-After' => '120' }
      )
    )

    with_cache do
      @name.check_wikispecies
      assert_nil(@name.reload.wikispecies_issues_text)
      assert_not(@name.wikispecies_checked_recently?)
      assert_equal(1, @requests.size)

      # Paused: no further requests until Retry-After has passed
      @name.check_wikispecies
      assert_equal(1, @requests.size)
    end
  end

  test 'external requests identify the Registry in the user agent' do
    headers = nil
    get_response = lambda do |_uri, request_headers|
      headers = request_headers
      response(Net::HTTPOK, '200')
    end

    Rails.configuration.stub(:bypass_external_apis, false) do
      Net::HTTP.stub(:get_response, get_response) do
        @name.external_response('https://species.wikimedia.org/wiki/X')
      end
    end

    assert_equal(
      HasExternalResources::EXTERNAL_USER_AGENT, headers['User-Agent']
    )
  end
end
