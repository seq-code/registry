require 'test_helper'

class NamesHistoryTest < ActionDispatch::IntegrationTest
  test 'shows public name history' do
    name = names(:escherichia_coli)
    name.update!(authority: 'Smith', etymology_xx_description: 'of the colon')

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-event', count: 1
    assert_select '.name-history-change', count: 2
    assert_select '.name-history-table thead th' do |headings|
      assert_equal %w[Date Attribute Before After], headings.map(&:text)
    end
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
    assert_select '.name-history-event', count: 0
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
    assert_select '.name-history-event', count: 3
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
    link.destroy!
    PublicationName.create!(name: name, publication: publication)

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-event', count: 4
    assert_select '.name-history-change th[scope=row]' do |labels|
      assert_equal ['Pub linked', 'Pub unlinked', 'Authority', 'Pub linked'], labels.map(&:text)
    end
    assert_select '.name-history-before a[href=?]', publication_path(publication),
                  text: publication.short_citation, count: 1
    assert_select '.name-history-after a[href=?]', publication_path(publication),
                  text: publication.short_citation, count: 2
  end

  test 'publication history remains readable after the publication and link are deleted' do
    name = names(:escherichia_coli)
    publication = publications(:no_doi)
    PublicationName.create!(name: name, publication: publication)
    publication.destroy!

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-event', count: 2
    assert_select '.name-history-before', text: "Publication ##{publication.id} (deleted)"
    assert_select '.name-history-after', text: "Publication ##{publication.id} (deleted)"
  end

  test 'annotation and external-resource updates do not crowd out public events' do
    name = names(:escherichia_coli)
    link = PublicationName.create!(name: name, publication: publications(:one))
    26.times do |index|
      link.update!(emends: index.even?, not_valid_proposal: index.even?)
      name.update!(wikispecies_checked_at: index.even? ? Time.current : nil)
    end
    other_name = Name.create!(name: 'E. coli', rank: 'species', status: 15)
    PublicationName.create!(name: other_name, publication: publications(:two))

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-event', count: 1
    assert_select '.name-history-change th[scope=row]', text: 'Pub linked'
  end

  test 'paginates one timeline of attribute and publication events with tied timestamps' do
    name = names(:escherichia_coli)
    travel_to Time.utc(2026, 10, 5, 12) do
      link = PublicationName.create!(name: name, publication: publications(:one))
      24.times { |index| name.update!(authority: "Smith #{index}") }
      link.destroy!
    end
    event_ids = name.history_events.order(id: :desc).pluck(:id)

    get history_name_path(name)

    assert_response :success
    assert_select '.name-history-event' do |events|
      assert_equal event_ids.first(25), events.map { |event| event['data-event-id'].to_i }
    end
    assert_select '.name-history-change th[scope=row]', text: 'Pub unlinked'

    get history_name_path(name), params: { page: 2 }

    assert_response :success
    assert_select '.name-history-event', count: 1
    assert_select '.name-history-event[data-event-id=?]', event_ids.last.to_s
    assert_select '.name-history-change th[scope=row]', text: 'Pub linked'
  end
end
