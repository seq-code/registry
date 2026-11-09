require 'test_helper'

class StrainsControllerTest < ActionDispatch::IntegrationTest
  test 'orphan strains show when they will be removed' do
    strain = Strain.create!(numbers_string: 'DSM 12345')
    strain.update_column(:updated_at, Time.utc(2026, 11, 10, 12))

    get strain_path(strain)

    assert_response :success
    assert_select '.alert-warning', /removed from the database after\s+May 10, 2027\s+\(6 months after its last update\)/
  end
end
