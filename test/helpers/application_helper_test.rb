require 'test_helper'
require 'minitest/mock'

class ApplicationHelperTest < ActionView::TestCase
  include FontAwesome5::Rails::IconHelper

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

  test 'icon_link_to names the link and hides the icon from screen readers' do
    assert_dom_equal(
      '<a class="icon-link" title="Genome page" aria-label="Genome page" ' \
        'href="/genomes/1"><i class="fas fa-dna" aria-hidden="true"></i></a>',
      icon_link_to('dna', 'Genome page', '/genomes/1')
    )
  end

  test 'icon_link_to keeps the link and icon options' do
    assert_dom_equal(
      '<a class="icon-link btn btn-sm" title="Delete notification" ' \
        'aria-label="Delete notification" data-method="delete" ' \
        'rel="nofollow" href="/notifications/1"><i ' \
        'class="fas fa-trash text-danger" aria-hidden="true"></i></a>',
      icon_link_to(
        'trash', 'Delete notification', '/notifications/1',
        icon_options: { class: 'text-danger' },
        class: 'btn btn-sm', method: :delete
      )
    )
  end
end
