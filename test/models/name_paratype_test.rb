require 'test_helper'

class NameParatypeTest < ActiveSupport::TestCase
  test 'name.paratype_strains returns the strains linked as paratypes' do
    name = names(:escherichia_coli)

    assert_includes(name.paratype_strains, strains(:one))
  end

  test 'requires a publication' do
    name_paratype = NameParatype.new(
      name: names(:bacillus_subtilis), nomenclatural_type: strains(:two),
      publication: nil
    )

    assert_not(name_paratype.valid?)
    assert_includes(name_paratype.errors.attribute_names, :publication)
  end

  test 'does not allow the same paratype to be linked twice to the same name' do
    name_paratype = NameParatype.new(
      name: names(:escherichia_coli), nomenclatural_type: strains(:one),
      publication: publications(:one)
    )

    assert_not(name_paratype.valid?)
    assert_includes(
      name_paratype.errors.attribute_names, :nomenclatural_type_id
    )
  end

  test 'allows the same strain as a paratype of a different name' do
    name_paratype = NameParatype.new(
      name: names(:bacillus_subtilis), nomenclatural_type: strains(:one),
      publication: publications(:one)
    )

    assert(name_paratype.valid?)
  end

  test 'links the paratype publication to the name if not already linked' do
    name = names(:bacillus_subtilis)
    publication = publications(:one)
    assert_not_includes(name.publications, publication)

    NameParatype.create!(
      name: name, nomenclatural_type: strains(:one), publication: publication
    )

    assert_includes(name.reload.publications, publication)
  end

  test 'does not duplicate an already-existing publication link' do
    name = names(:bacillus_subtilis)
    publication = publications(:one)
    PublicationName.create!(publication: publication, name: name)

    assert_no_difference('PublicationName.count') do
      NameParatype.create!(
        name: name, nomenclatural_type: strains(:one), publication: publication
      )
    end
  end

  test 'only allows strains as paratypes' do
    name_paratype = NameParatype.new(
      name: names(:bacillus_subtilis), nomenclatural_type: genomes(:one),
      publication: publications(:one)
    )

    assert_not(name_paratype.valid?)
    assert_includes(
      name_paratype.errors.attribute_names, :nomenclatural_type_type
    )
  end
end
