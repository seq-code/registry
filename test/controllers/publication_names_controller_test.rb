require 'test_helper'

class PublicationNamesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in(users(:contributor))
    @name = names(:escherichia_coli)
    @publication = publications(:no_doi)
  end

  test 'linking and unlinking records events in the names public history' do
    post link_publication_commit_name_url(@publication),
         params: { publication_name: { name: @name.name } }

    assert_redirected_to @publication
    link = @name.publication_names.find_by!(publication: @publication)
    @name.update!(proposed_in: @publication)

    delete publication_name_url(link)

    assert_redirected_to @publication
    assert_not PublicationName.exists?(link.id)
    assert_nil @name.reload.proposed_in
    get history_name_path(@name)
    assert_response :success
    assert_select '.name-history-change th[scope=row]', text: 'Pub linked', count: 1
    assert_select '.name-history-change th[scope=row]', text: 'Pub unlinked', count: 1
  end

  test 'failed name validation leaves the publication linked with no unlink event' do
    link = PublicationName.create!(name: @name, publication: @publication)
    @name.update_columns(proposed_in_id: @publication.id, syllabication: 'co li')

    assert_no_difference -> { @name.history_events.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        delete publication_name_url(link)
      end
    end

    assert PublicationName.exists?(link.id)
    assert_equal @publication.id, @name.reload.proposed_in_id
  end
end
