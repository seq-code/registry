require 'application_system_test_case'

class NamesTest < ApplicationSystemTestCase
  setup do
    @user = users(:contributor)
  end

  # test "visiting the index" do
  #   visit names_url
  #
  #   assert_selector "h1", text: "Name"
  # end
end
