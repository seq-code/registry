json.response do
  json.status 'ok'
  json.message_type 'genomes'
  json.(@genomes, :count, :current_page, :total_pages)
  json.next(
    @genomes.next_page ?
      genomes_url(format: :json, page: @genomes.next_page) : nil
  )
end
json.values(@genomes, partial: 'genomes/genome_item', as: :genome)
