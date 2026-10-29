require 'test_helper'

class PublicationNameTest < ActiveSupport::TestCase
  test 'displays the short citation of its publication' do
    publication = publications(:one)
    link = PublicationName.new(name: names(:escherichia_coli), publication: publication)

    assert_equal publication.short_citation, link.display
  end
  test 'deleting a name removes both current and historical publication links' do
    name = names(:escherichia_coli)
    old_link = PublicationName.create!(name: name, publication: publications(:one))
    old_link.soft_delete!
    current_link = PublicationName.create!(name: name, publication: publications(:one))

    name.destroy!

    assert_empty PublicationName.with_deleted.where(id: [old_link.id, current_link.id])
  end

  test 'deleting a publication removes its historical links' do
    publication = publications(:one).dup
    publication.doi = nil
    publication.save!
    link = PublicationName.create!(name: names(:escherichia_coli), publication: publication)
    link.soft_delete!

    publication.destroy!

    assert_not PublicationName.with_deleted.exists?(link.id)
  end

end
