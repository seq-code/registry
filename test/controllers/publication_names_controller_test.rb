require 'test_helper'

class PublicationNamesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in(users(:contributor))
    @name = names(:escherichia_coli)
    @publication = publications(:no_doi)
    @publication_name = PublicationName.create!(
      name: @name, publication: @publication,
      emends: true, not_valid_proposal: true
    )
  end

  test 'unlinking soft deletes the relationship and clears publication roles and citations' do
    @name.update!(
      proposed_in: @publication, assigned_in: @publication,
      corrigendum_in: @publication, corrigendum_from: 'Escherichia colie'
    )

    delete publication_name_url(@publication_name)

    assert_redirected_to @publication
    @publication_name.reload
    assert @publication_name.deleted?
    assert @publication_name.emends?
    assert @publication_name.not_valid_proposal?
    @name.reload
    assert_nil @name.proposed_in
    assert_nil @name.assigned_in
    assert_nil @name.corrigendum_in
    assert_nil @name.corrigendum_from
    assert_empty @name.citations
  end

  test 'relinking creates a fresh relationship without the old flags' do
    delete publication_name_url(@publication_name)

    post(
      link_publication_commit_name_url(@publication),
      params: { publication_name: { name: @name.name } }
    )

    assert_redirected_to @publication
    replacement = @name.reload.publication_names.find_by!(publication: @publication)
    assert_not_equal @publication_name.id, replacement.id
    assert_not replacement.emends?
    assert_not replacement.not_valid_proposal?
    assert @publication_name.reload.deleted?
  end
end
