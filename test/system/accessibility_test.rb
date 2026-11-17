require 'application_system_test_case'

# Checks the most visited public pages against WCAG 2.1 Level AA with axe-core
# (see issue #117). Automated checks find only part of the accessibility
# issues, so these complement manual keyboard and screen reader testing
class AccessibilityTest < ApplicationSystemTestCase
  test 'home page' do
    visit root_path

    assert_accessible
  end

  test 'search results' do
    visit search_path(what: :names, q: 'Escherichia')

    assert_accessible
  end

  test 'names index' do
    visit names_path

    assert_accessible
  end

  test 'name page' do
    visit name_path(names(:escherichia_coli))

    assert_accessible
  end

  test 'register list page' do
    visit register_path(registers(:submitted))

    assert_accessible
  end

  test 'genome page' do
    visit genome_path(genomes(:with_locations))

    assert_accessible
  end

  test 'publication page' do
    visit publication_path(publications(:one))

    assert_accessible
  end

  test 'help page' do
    visit help_path(:register)

    assert_accessible
  end

  test 'sign in page' do
    visit new_user_session_path

    assert_accessible
  end

  test 'sign up page' do
    visit new_user_registration_path

    assert_accessible
  end
end
