module Name::Citations
  def pull_citations
    publications = []

    vars = [base_name]
    vars << corrigendum_from.gsub(/^Candidatus /) if corrigendum_from?
    vars.each do |q|
      query = { query: "'#{q}'", sort: 'deposited', order: 'asc' }
      Publication.query_crossref(query) do |publication|
        publications << publication
        yield(publication) if block_given?
      end
    end

    self.publications += publications - self.publications
    publications
  end
end

