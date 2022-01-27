module Name::Citations
  def pull_citations
    publications = []

    vars = [base_name]
    vars << corrigendum_from.gsub(/^Candidatus /) if corrigendum_from?

    if %w[species subspecies].include?(rank)
      return publications unless genus

      vars += vars.map { |i| i.gsub(/^(\S)\S+ /, '\1. ') }
      genus.pull_citations
      genus.publications.each do |publication|
        next if publications.include?(publication)
        next unless vars.any? { |q| publication.include_term?(q) }

        publications << publication
        yield(publication) if block_given?
      end
    else
      vars.each do |q|
        query = { query: q, sort: 'deposited', order: 'asc' }
        Publication.query_crossref(query) do |publication|
          unless publications.include?(publication)
            publications << publication
            yield(publication) if block_given?
          end
        end
      end
    end

    self.publications += publications - self.publications
    publications
  end
end

