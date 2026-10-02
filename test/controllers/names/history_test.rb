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

  test 'renders proposed publication changes as citations with links' do
    name = names(:escherichia_coli)
    first = publications(:one)
    second = publications(:two)
    name.update!(proposed_in: first)
    name.update!(proposed_in: second)
    name.update!(proposed_in: nil)

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 3
    assert_select '.name-history-before a[href=?]', publication_path(first), text: first.short_citation
    assert_select '.name-history-after a[href=?]', publication_path(first), text: first.short_citation
    assert_select '.name-history-before a[href=?]', publication_path(second), text: second.short_citation
    assert_select '.name-history-after a[href=?]', publication_path(second), text: second.short_citation
    assert_select '.name-history-before', text: '—', count: 1
    assert_select '.name-history-after', text: '—', count: 1
  end

  test 'renders a retained publication id when the publication no longer exists' do
    name = names(:escherichia_coli)
    publication = publications(:no_doi)
    name.update!(proposed_in: publication)
    publication.destroy!

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-after', text: "Publication ##{publication.id} (deleted)"
  end
end
