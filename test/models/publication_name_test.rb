require 'test_helper'

class PublicationNameTest < ActiveSupport::TestCase
  test 'updating a link records its publication alongside the change' do
    publication = publications(:one)
    link = PublicationName.create!(name: names(:escherichia_coli), publication: publication)

    link.update!(emends: true)

    assert_equal(
      { 'publication_id' => [publication.id, publication.id], 'emends' => [false, true] },
      link.versions.last.changeset.except('updated_at')
    )
  end

  test 'updating only timestamps does not add a version for its publication alone' do
    link = PublicationName.create!(name: names(:escherichia_coli), publication: publications(:one))

    assert_no_difference -> { link.versions.count } do
      link.update!(updated_at: 1.hour.ago)
    end
  end
end
