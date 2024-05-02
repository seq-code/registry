json.partial! 'publications/publication_item', publication: publication
json.link_ext publication.url
json.extract!(
  publication,
  :title, :journal, :journal_loc, :journal_date, :pub_type,
  :abstract, :long_citation_html, :created_at, :updated_at
)
json.authors(publication.authors, partial: 'authors/author', as: :author)
json.names(publication.names, partial: 'names/name_item', as: :name)
json.subjects(
  publication.subjects, partial: 'subjects/subject_item', as: :subject
)
