require 'test_helper'

class Names::HistoriesControllerTest < ActionDispatch::IntegrationTest
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
    PublicationName.create!(name: name, publication: publications(:one)).unlink!

    get name_history_path(name)

    assert_select 'h3', text: 'Insufficient permits'
    assert_select '.name-history-version', count: 0
  end

  test 'renders changes to types classification and publication roles' do
    name = names(:escherichia_coli)
    name.update!(nomenclatural_type: strains(:one))
    name.update!(
      parent: nil, nomenclatural_type: strains(:two),
      corrigendum_in: publications(:one)
    )

    get name_history_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 2
    assert_select '.name-history-change a[href=?]', strain_path(strains(:one)), count: 2
    assert_select '.name-history-change a[href=?]', strain_path(strains(:two)), count: 1
    assert_select '.name-history-change a[href=?]', name_path(names(:escherichia)), count: 1
    assert_select '.name-history-change a[href=?]', publication_path(publications(:one)), count: 1
  end
end
