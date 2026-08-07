require 'test_helper'

class NamesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @name = names(:unregistered)
    @user = users(:contributor)
    sign_in(@user)
  end

  test 'submits a new name' do
    assert_difference('Name.count', 1) do
      post names_url, params: { name: { name: 'Testimonas exampleensis' } }
    end

    name = Name.find_by!(name: 'Testimonas exampleensis')

    assert_equal 'Draft', name.status_name
    assert_equal @user, name.created_by
    assert name.observing?(@user)
    assert_redirected_to name_url(name)
  end

  test 'user names includes draft names' do
    get user_names_url

    assert_response :success
    assert_includes @response.body, names(:draft_by_contributor).name
  end

  test 'type_genomes JSON reports the nomenclatural type class as Genome' do
    get name_type_genomes_url(format: :json)

    assert_response :success
    json = JSON.parse(response.body)
    entry = json['values'].find do |v|
      v['id'] == names(:type_genome_with_locations).id
    end

    assert(entry, 'expected the type genome fixture in the response')
    assert_equal('Genome', entry['nomenclatural_type']['class'])
  end
end
