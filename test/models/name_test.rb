require 'test_helper'

class NameTest < ActiveSupport::TestCase
  test 'ranks at or above returns ranks from domain through the given rank' do
    assert_equal %w[domain phylum class], Name.ranks_at_or_above('class')
  end

  test 'ranks at or above returns nil for an unknown rank' do
    assert_nil Name.ranks_at_or_above('strain')
  end

  test 'add_to_register adds name to a draft register' do
    name = names(:unregistered)
    register = registers(:draft)

    assert register.draft?
    assert name.add_to_register(register, users(:contributor))
    assert_equal register, name.reload.register
  end

  test 'add_to_register refuses non-draft registers' do
    name = names(:unregistered)
    register = registers(:submitted)

    assert_not register.draft?
    assert_not name.add_to_register(register, users(:contributor))
    assert_includes name.errors[:register], 'must be a draft'
    assert_nil name.reload.register
  end

  test 'incertae sedis HTML comes from the preferred placement' do
    name = names(:incertae_sedis)

    assert_equal(
      '<i>Incertae sedis</i> (Bacteria)', name.incertae_sedis_html
    )
  end

  test 'permanently deleting a name removes both active and soft deleted publication links' do
    name = names(:escherichia_coli)
    publication = publications(:no_doi)
    soft_deleted_link = PublicationName.create!(name: name, publication: publication)
    soft_deleted_link.soft_delete!
    active_link = PublicationName.create!(name: name, publication: publication)

    name.destroy!

    assert_not PublicationName.with_deleted.exists?(soft_deleted_link.id)
    assert_not PublicationName.with_deleted.exists?(active_link.id)
  end
end
