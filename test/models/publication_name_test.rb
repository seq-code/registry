require 'test_helper'

class PublicationNameTest < ActiveSupport::TestCase
  test 'records link annotations and soft deletion in the relationship history' do
    link = PublicationName.create!(
      name: names(:escherichia_coli), publication: publications(:one)
    )
    link.update!(emends: true, not_valid_proposal: true)
    link.soft_delete!

    created, annotated, unlinked = link.versions.order(:id).to_a
    assert_equal 'create', created.operation
    assert_equal 'update', annotated.operation
    assert_equal({ 'emends' => [false, true], 'not_valid_proposal' => [false, true] },
                 annotated.changeset)
    assert_equal 'update', unlinked.operation
    assert_nil unlinked.changeset['deleted_at'].first
    assert_equal link.deleted_at.iso8601(3), unlinked.changeset['deleted_at'].last
  end
end
