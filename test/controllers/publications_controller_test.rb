require 'test_helper'

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @publication = publications(:one)
  end

  test 'curator can register a publication without a doi' do
    sign_in(users(:curator))

    assert_difference('Publication.count', 1) do
      post(
        publications_url,
        params: {
          publication: {
            doi: '', title: 'A Manually Entered Paper',
            journal: 'Journal of Examples',
            journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
          }
        }
      )
    end

    publication = Publication.find_by(title: 'A Manually Entered Paper')
    assert_not_nil publication
    assert_nil publication.doi
    assert_redirected_to publication
  end

  test 'non-curator cannot register a publication without a doi' do
    sign_in(users(:contributor))

    assert_no_difference('Publication.count') do
      post(
        publications_url,
        params: {
          publication: {
            doi: '', title: 'A Manually Entered Paper',
            journal: 'Journal of Examples',
            journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
          }
        }
      )
    end

    assert_response :success
    assert_includes @response.body, 'New Publication'
  end
end
