require 'test_helper'
require 'minitest/mock'

class TaggingService::AnthropicBackendTest < ActiveSupport::TestCase
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
end
