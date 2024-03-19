require 'application_system_test_case'

class RegistersTest < ApplicationSystemTestCase
  setup do
    @register = registers(:one)
  end

  test 'visiting the index' do
    visit registers_url
    assert_selector 'h1', text: 'Registers'
  end

  test 'creating a Register' do
    visit registers_url
    click_on 'New Register'

    fill_in 'Accession', with: @register.accession
    fill_in 'Publication', with: @register.publication_id
    check 'Submitted' if @register.submitted
    fill_in 'User', with: @register.user_id
    check 'Validated' if @register.validated
    fill_in 'Validated by', with: @register.validated_by
    click_on 'Create Register'

    assert_text 'Register was successfully created'
    click_on 'Back'
  end

  test 'updating a Register' do
    visit registers_url
    click_on 'Edit', match: :first

    fill_in 'Accession', with: @register.accession
    fill_in 'Publication', with: @register.publication_id
    check 'Submitted' if @register.submitted
    fill_in 'User', with: @register.user_id
    check 'Validated' if @register.validated
    fill_in 'Validated by', with: @register.validated_by
    click_on 'Update Register'

    assert_text 'Register was successfully updated'
    click_on 'Back'
  end

  test 'destroying a Register' do
    visit registers_url
    page.accept_confirm do
      click_on 'Destroy', match: :first
    end

    assert_text 'Register was successfully destroyed'
  end
end
