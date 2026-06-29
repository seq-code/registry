require 'test_helper'

class RegistersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @contributor = users(:contributor)
    @curator = users(:curator)
    @register = registers(:draft)
    @submitted_register = registers(:submitted)
    @notified_register = registers(:notified)
  end

  test 'draft index only includes draft registers' do
    sign_in(@curator)

    get registers_path(status: :draft)

    assert_response :success
    assert_includes response.body, @register.acc_url
    assert_not_includes response.body, @submitted_register.acc_url
    assert_not_includes response.body, @notified_register.acc_url
  end

  test 'new register form only offers draft registers' do
    sign_in(@contributor)

    get new_register_path

    assert_response :success
    assert_select 'select[name=existing_register]' do |select|
      options = select.css('option').map(&:text).join(' ')
      assert_includes options, @register.accession
      assert_not_includes options, @submitted_register.accession
      assert_not_includes options, @notified_register.accession
    end
  end
end
