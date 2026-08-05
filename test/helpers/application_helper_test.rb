require 'test_helper'
require 'minitest/mock'

class ApplicationHelperTest < ActionView::TestCase
  test 'maptiler_key uses the development key outside production' do
    Rails.application.credentials.stub(
      :dig, ->(*keys) { 'dev-key' if keys == [:maptiler, :development_key] }
    ) do
      assert_equal('dev-key', maptiler_key)
    end
  end

  test 'maptiler_key uses the production key in production' do
    Rails.env.stub(:production?, true) do
      Rails.application.credentials.stub(
        :dig, ->(*keys) { 'prod-key' if keys == [:maptiler, :key] }
      ) do
        assert_equal('prod-key', maptiler_key)
      end
    end
  end

  test 'maptiler_key falls back to the shared placeholder when unset' do
    Rails.application.credentials.stub(:dig, nil) do
      assert_equal('get_your_own_OpIi9ZULNHzrESv6T2vL', maptiler_key)
    end
  end
end
