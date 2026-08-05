require 'application_system_test_case'

class RegistersTest < ApplicationSystemTestCase
  setup do
    @register = registers(:draft)
    @submitted_register = registers(:submitted)
  end

  test 'sample_map page renders a working map' do
    visit sample_map_register_path(@submitted_register)

    assert_selector('#map canvas')
  end

  test 'sample map modal on the register page renders a working map' do
    visit register_path(@submitted_register)

    click_link('View map of sampling locations')

    within('.modal.show') do
      assert_selector('#map canvas')
    end
  end
end
