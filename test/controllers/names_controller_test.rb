require 'test_helper'

class NamesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @name = names(:unregistered)
    @user = users(:contributor)
    sign_in(@user)
  end

  test 'submits a new name' do
    assert_difference('Name.count', 1) do
      post names_url, params: { name: { name: 'Testimonas exampleensis' } }
    end

    name = Name.find_by!(name: 'Testimonas exampleensis')

    assert_equal 'Draft', name.status_name
    assert_equal @user, name.created_by
    assert name.observing?(@user)
    assert_redirected_to name_url(name)
  end
end
