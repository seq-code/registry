require "test_helper"

class StrainTest < ActiveSupport::TestCase
  test 'paratypified_names returns names for which the strain is a paratype' do
    strain = strains(:one)

    assert_includes(strain.paratypified_names, names(:escherichia_coli))
    assert_not_includes(strain.paratypified_names, names(:bacillus_subtilis))
  end
end
