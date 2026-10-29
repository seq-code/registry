require 'test_helper'

class Names::HistoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'renders public history' do
    name = names(:escherichia_coli)
    name.update!(authority: 'Smith', etymology_xx_description: 'of the colon')
    PublicationName.create!(name: name, publication: publications(:one))

    get name_history_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 2
  end

  test 'does not reveal private name history' do
    name = Name.create!(
      name: 'E. coli', rank: 'species', status: 5, created_by: users(:contributor)
    )
    name.update!(syllabication: 'co.li')

    get name_history_path(name)

    assert_select 'h3', text: 'Insufficient permits'
    assert_select '.name-history-version', count: 0
  end
end
