Rails.application.routes.draw do
  resources :tutorials
  # Static pages
  get  'page/publications', as: :page_publications
  get  'page/seqcode',      as: :page_seqcode
  get  'page/initiative',   as: :page_initiative
  get  'page/connect',      as: :page_connect
  get  'page/join',         as: :page_join
  get  'page/about',        as: :page_about
  get  'page/committee'
  get  'help/etymology' => 'page#etymology_help', as: :help_etymology

  resources(:genomes)
  root(to: 'application#main')

  post 'check/:name_id.json' => 'checks#update', as: :check

  resources(:registers, param: :accession)
  devise_for(:users, controllers: { registrations: 'users/registrations' })
  get  'link' => 'application#short_link'
  get  'link/:path(.:format)' => 'application#short_link'
  get  'set/list' => 'application#set_list', as: :set_list
  get  'sysusers(.:format)' => 'users#index', as: :users
  get  'sysusers/:username(.:format)' => 'users#show', as: :user
  get  'dashboard' => 'users#dashboard', as: :dashboard
  get  'contributors' => 'users#contributor_request', as: :contributor_request
  post 'contributors' => 'users#contributor_apply', as: :contributor_apply
  post 'contributors/grant/:username' => 'users#contributor_grant', as: :contributor_grant
  post 'contributors/deny/:username' => 'users#contributor_deny', as: :contributor_deny
  get  'curators' => 'users#curator_request', as: :curator_request
  post 'curators' => 'users#curator_apply', as: :curator_apply
  post 'curators/grant/:username' => 'users#curator_grant', as: :curator_grant
  post 'curators/deny/:username' => 'users#curator_deny', as: :curator_deny
  get  'check_ranks' => 'names#check_ranks', as: :check_ranks
  get  'unknown_proposal' => 'names#unknown_proposal', as: :unknown_proposal
  get  'submitted' => 'names#submitted', as: :submitted_names
  get  'endorsed'  => 'names#endorsed',  as: :endorsed_names
  get  'drafts'    => 'names#drafts',    as: :draft_names
  get  'user-names' => 'names#user_names', as: :user_names
  get  'search' => 'application#search', as: :search
  get  'type-genomes(.:format)' => 'names#type_genomes', as: :name_type_genomes

  resources(:names)
  resources :authors
  resources :publication_names
  get  'doi/:doi' => 'publications#show', as: :doi, doi: /.+/
  get  'publications/:id/link_names' => 'publication_names#link_names', as: :link_publication_name
  post 'publications/:id/link_names' => 'publication_names#link_names_commit', as: :link_publication_commit_name
  post 'names/:id/proposed_by/:publication_id' => 'names#proposed_by', as: :proposed_by_name
  get  'names/:id/corrigendum_by/:publication_id' => 'names#corrigendum_by', as: :corrigendum_by_name
  post 'names/:id/corrigendum' => 'names#corrigendum', as: :corrigendum_name
  post 'names/:id/emended_by/:publication_id' => 'names#emended_by', as: :emended_by_name
  post 'names/:id/assigned_by/:publication_id' => 'names#assigned_by', as: :assigned_by_name
  get  'names/:id/edit_etymology' => 'names#edit_etymology', as: :edit_etymology_name
  get  'names/:id/autofill_etymology' => 'names#autofill_etymology', as: :autofill_etymology_name
  get  'names/:id/edit_notes' => 'names#edit_notes', as: :edit_notes_name
  get  'names/:id/edit_rank' => 'names#edit_rank', as: :edit_rank_name
  get  'names/:id/edit_links' => 'names#edit_links', as: :edit_links_name
  get  'names/:id/link_parent' => 'names#link_parent', as: :link_parent_name
  get  'names/:id/type' => 'names#edit_type', as: :edit_type_name
  post 'names/:id/link_parent' => 'names#link_parent_commit', as: :link_parent_commit_name
  post 'names/:id/return' => 'names#return', as: :return_name
  post 'names/:id/validate' => 'names#validate', as: :validate_name
  post 'names/:id/endorse' => 'names#endorse', as: :endorse_name
  post 'names/:id/claim' => 'names#claim', as: :claim_name
  post 'names/:id/unclaim' => 'names#unclaim', as: :unclaim_name
  post 'names/:id/new_correspondence' => 'names#new_correspondence', as: :new_correspondence_name

  get  'placements/new/:name_id' => 'placements#new', as: :new_placement
  post 'placements'     => 'placements#create', as: :create_placement
  get  'placements/:id' => 'placements#edit', as: :edit_placement
  post 'placements/:id' => 'placements#update', as: :update_placement
  post 'placements/:id/prefer' => 'placements#prefer', as: :prefer_placement
  delete 'placements/:id' => 'placements#destroy', as: :destroy_placement

  post 'registers/:accession/submit' => 'registers#submit', as: :submit_register
  get  'registers/:accession/return' => 'registers#return', as: :return_register
  post 'registers/:accession/return' => 'registers#return_commit', as: :post_return_register
  post 'registers/:accession/endorse' => 'registers#endorse', as: :endorse_register
  get  'registers/:accession/notify' => 'registers#notification', as: :notification_register
  post 'registers/:accession/notify' => 'registers#notify', as: :notify_register
  get  'registers/:accession/table(.:format)' => 'registers#table', as: :download_register_table
  get  'registers/:accession/list(.:format)' => 'registers#list', as: :download_register_list
  get  'registers/:accession/cite(.:format)' => 'registers#cite', as: :cite_register_list
  post 'registers/:accession/validate' => 'registers#validate', as: :validate_register
  post 'registers/:accession/publish' => 'registers#publish', as: :publish_register
  post 'registers/:accession/new_correspondence' => 'registers#new_correspondence', as: :new_correspondence_register
  patch 'registers/:accession/internal_notes' => 'registers#internal_notes', as: :internal_notes_register
  post 'registers/:accession/nomenclature_review' => 'registers#nomenclature_review', as: :nomenclature_review_register
  post 'registers/:accession/genomics_review' => 'registers#genomics_review', as: :genomics_review_register
  resources(:publications)
  resources(:subjects)

  # Helpers
  get  'autocomplete_names.json' => 'names#autocomplete', as: :autocomplete_names
  get  'autocomplete_publications.json' => 'publications#autocomplete', as: :autocomplete_publications
end
