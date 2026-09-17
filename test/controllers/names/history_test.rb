require 'test_helper'

class NamesHistoryTest < ActionDispatch::IntegrationTest
  test 'shows public name history' do
    name = names(:escherichia_coli)
    name.update!(authority: 'Smith', etymology_xx_description: 'of the colon')

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 1
    assert_select '.name-history-change', count: 2
  end

  test 'shows an empty state without recorded history' do
    get history_name_path(names(:escherichia_coli))

    assert_response :success
    assert_select 'p', text: 'No history has been recorded for this name.'
  end

  test 'does not reveal private name history' do
    name = names(:draft_by_contributor)
    name.update!(syllabication: 'co.li')

    get history_name_path(name)

    assert_select 'h3', text: 'Insufficient permits'
    assert_select '.name-history-version', count: 0
  end
end
