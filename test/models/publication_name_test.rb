require 'test_helper'

class PublicationNameTest < ActiveSupport::TestCase
  test 'publication events retain their context after the relationship is destroyed' do
    name = names(:escherichia_coli)
    publication = publications(:one)
    link = PublicationName.create!(name: name, publication: publication)
    link.update!(emends: true, not_valid_proposal: true)
    link.destroy!

    events = name.history_events.order(:id)
    assert_equal %w[publication_linked publication_unlinked], events.pluck(:kind)
    assert_equal [{ 'publication_id' => publication.id }] * 2, events.pluck(:data)
    assert_not PublicationName.exists?(link.id)
  end

  test 'rolling back an unlink restores the relationship and removes its event' do
    name = names(:escherichia_coli)
    link = PublicationName.create!(name: name, publication: publications(:one))

    assert_no_difference -> { name.history_events.count } do
      PublicationName.transaction do
        link.destroy!
        raise ActiveRecord::Rollback
      end
    end

    assert PublicationName.exists?(link.id)
  end

  test 'deleting the name retains its publication history without the join records' do
    name = names(:escherichia_coli)
    publication = publications(:one)
    link = PublicationName.create!(name: name, publication: publication)

    name.destroy!

    assert_not PublicationName.exists?(link.id)
    events = NameHistoryEvent.where(name_id: name.id).order(:id)
    assert_equal %w[publication_linked publication_unlinked], events.pluck(:kind)
    assert_equal [{ 'publication_id' => publication.id }] * 2, events.pluck(:data)
  end
end
