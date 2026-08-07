require 'test_helper'

class TypeResolverServiceTest < ActiveSupport::TestCase
  test 'resolves a Genome to the literal class name, not its source database' do
    genome = genomes(:one)
    genome.database = 'assembly'

    assert_equal('Genome', TypeResolverService.resolve(genome))
  end

  test 'resolves a Strain and a Name to their literal class names' do
    assert_equal('Strain', TypeResolverService.resolve(strains(:one)))
    assert_equal('Name', TypeResolverService.resolve(names(:unregistered)))
  end

  test 'resolves nil or an object without type_of_type to unknown' do
    assert_equal('unknown', TypeResolverService.resolve(nil))
    assert_equal('unknown', TypeResolverService.resolve(Object.new))
  end

  test 'resolve_with_context falls back only when unresolved' do
    genome = genomes(:one)

    assert_equal(
      'Genome', TypeResolverService.resolve_with_context(genome, fallback: 'X')
    )
    assert_equal(
      'X', TypeResolverService.resolve_with_context(nil, fallback: 'X')
    )
  end
end
