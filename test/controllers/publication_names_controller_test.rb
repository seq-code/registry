require 'test_helper'

class PublicationNamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @publication_name = publication_names(:one)
  end

  test 'should get index' do
    get publication_names_url
    assert_response :success
  end

  test 'should get new' do
    get new_publication_name_url
    assert_response :success
  end

  test 'should create publication_name' do
    assert_difference('PublicationName.count') do
      post publication_names_url, params: { publication_name: { name_id: @publication_name.name_id, publication_id: @publication_name.publication_id } }
    end

    assert_redirected_to publication_name_url(PublicationName.last)
  end

  test 'should show publication_name' do
    get publication_name_url(@publication_name)
    assert_response :success
  end

  test 'should get edit' do
    get edit_publication_name_url(@publication_name)
    assert_response :success
  end

  test 'should update publication_name' do
    patch publication_name_url(@publication_name), params: { publication_name: { name_id: @publication_name.name_id, publication_id: @publication_name.publication_id } }
    assert_redirected_to publication_name_url(@publication_name)
  end

  test 'should destroy publication_name' do
    assert_difference('PublicationName.count', -1) do
      delete publication_name_url(@publication_name)
    end

    assert_redirected_to publication_names_url
  end
end
