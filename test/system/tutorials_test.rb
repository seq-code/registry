require "application_system_test_case"

class TutorialsTest < ApplicationSystemTestCase
  setup do
    @tutorial = tutorials(:one)
  end

  test "visiting the index" do
    visit tutorials_url
    assert_selector "h1", text: "Tutorials"
  end

  test "creating a Tutorial" do
    visit tutorials_url
    click_on "New Tutorial"

    check "Ongoing" if @tutorial.ongoing
    fill_in "Pipeline", with: @tutorial.pipeline
    fill_in "Step", with: @tutorial.step
    fill_in "User", with: @tutorial.user_id
    click_on "Create Tutorial"

    assert_text "Tutorial was successfully created"
    click_on "Back"
  end

  test "updating a Tutorial" do
    visit tutorials_url
    click_on "Edit", match: :first

    check "Ongoing" if @tutorial.ongoing
    fill_in "Pipeline", with: @tutorial.pipeline
    fill_in "Step", with: @tutorial.step
    fill_in "User", with: @tutorial.user_id
    click_on "Update Tutorial"

    assert_text "Tutorial was successfully updated"
    click_on "Back"
  end

  test "destroying a Tutorial" do
    visit tutorials_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Tutorial was successfully destroyed"
  end
end
