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

  test 'shows the user who made a change' do
    name = names(:escherichia_coli)
    curator = users(:curator)
    sign_in(curator)
    patch name_path(name), params: { name: { gtdb_accession: 's__Escherichia coli' } }
    name.update!(syllabication: 'co.li')

    get name_history_path(name)

    assert_select '.name-history-author', text: curator.username, count: 1
  end

  test 'renders description edits as changes of the name' do
    name = names(:escherichia_coli)
    name.update!(description: 'A gut bacterium')
    name.reload.update!(description: 'A commensal gut bacterium')

    get name_history_path(name)

    assert_response :success
    assert_select '.name-history-version', count: 2
    assert_select '.name-history-after ins', text: /commensal/
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
    # Clearing the parent also stops preferring its placement.
    assert_select '.name-history-version', count: 3
    assert_select '.name-history-change a[href=?]', strain_path(strains(:one)), count: 2
    assert_select '.name-history-change a[href=?]', strain_path(strains(:two)), count: 1
    assert_select '.name-history-change a[href=?]', name_path(names(:escherichia)), count: 1
    assert_select '.name-history-change a[href=?]', publication_path(publications(:one)), count: 1
  end

  test 'renders unlinked placements' do
    name = names(:escherichia_coli)
    Placement.create!(
      name: name, parent: names(:bacteria), incertae_sedis: true,
      incertae_sedis_text: 'Family placement unresolved'
    ).unlink!

    get name_history_path(name)

    assert_response :success
    assert_select '.name-history-record', text: /Placement:\s+incertae sedis \(Bacteria\)/, count: 2
  end
end
