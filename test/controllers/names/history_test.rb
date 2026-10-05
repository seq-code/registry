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
    name = Name.create!(
      name: 'E. coli', rank: 'species', status: 5, created_by: users(:contributor)
    )
    name.update!(syllabication: 'co.li')
    PublicationName.create!(name: name, publication: publications(:one))

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

  test 'shows publication links, unlinks and relinks alongside name updates' do
    name = names(:escherichia_coli)
    publication = publications(:one)
    link = PublicationName.create!(name: name, publication: publication)
    name.update!(authority: 'Smith')
    link.soft_delete!
    PublicationName.create!(name: name, publication: publication)

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 4
    assert_select '.name-history-change th[scope=row]' do |labels|
      assert_equal ['Pub linked', 'Pub unlinked', 'Authority', 'Pub linked'], labels.map(&:text)
    end
    assert_select '.name-history-before a[href=?]', publication_path(publication),
                  text: publication.short_citation, count: 1
    assert_select '.name-history-after a[href=?]', publication_path(publication),
                  text: publication.short_citation, count: 2
  end

  test 'shows unlinking a publication linked before versioning was enabled' do
    name = names(:escherichia_coli)
    publication = publications(:one)
    link = PublicationName.create!(name: name, publication: publication)
    Version.where(record: link).delete_all
    link.soft_delete!

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 1
    assert_select '.name-history-change th[scope=row]', text: 'Pub unlinked'
    assert_select '.name-history-before a[href=?]', publication_path(publication),
                  text: publication.short_citation
    assert_select '.name-history-after', text: '—'
  end

  test 'only shows deletion state changes as unlink and link events' do
    name = names(:escherichia_coli)
    link = PublicationName.create!(name: name, publication: publications(:one))
    link.soft_delete!
    travel 1.minute do
      link.soft_delete!
    end
    link.update!(deleted_at: nil)

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 3
    assert_select '.name-history-change th[scope=row]', text: 'Pub linked', count: 2
    assert_select '.name-history-change th[scope=row]', text: 'Pub unlinked', count: 1
  end

  test 'filters publication annotations and other names before pagination' do
    name = names(:escherichia_coli)
    link = PublicationName.create!(name: name, publication: publications(:one))
    26.times { |index| link.update!(emends: index.even?) }
    other_name = Name.create!(name: 'E. coli', rank: 'species', status: 15)
    PublicationName.create!(name: other_name, publication: publications(:two))

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 1
    assert_select '.name-history-change th[scope=row]', text: 'Pub linked'
  end
end
