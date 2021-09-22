Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: 'users/registrations' }
  get 'set/list' => 'application#set_list', as: :set_list
  get 'sysusers(.:format)' => 'users#index', as: :users
  get 'sysusers/:username(.:format)' => 'users#show', as: :user
  get 'dashboard' => 'users#dashboard', as: :dashboard
  get 'contributors' => 'users#contributor_request', as: :contributor_request
  post 'contributors' => 'users#contributor_apply', as: :contributor_apply
  post 'contributors/grant/:username' => 'users#contributor_grant', as: :contributor_grant
  post 'contributors/deny/:username' => 'users#contributor_deny', as: :contributor_deny
  get 'curators' => 'users#curator_request', as: :curator_request
  post 'curators' => 'users#curator_apply', as: :curator_apply
  post 'curators/grant/:username' => 'users#curator_grant', as: :curator_grant
  post 'curators/deny/:username' => 'users#curator_deny', as: :curator_deny
  get 'check_ranks' => 'names#check_ranks', as: :check_ranks
  get 'unknown_proposal' => 'names#unknown_proposal', as: :unknown_proposal
  get 'submitted' => 'names#submitted', as: :submitted_names
  get 'user-names' => 'names#user_names', as: :user_names
  root to: 'application#main'
  get 'search' => 'application#search', as: :search
  get 'names/batch' => 'names#batch', as: :new_name_batch
  resources :names
  resources :authors
  resources :publication_names
  get 'doi/:doi' => 'publications#show', as: :doi, doi: /.+/
  get 'publications/:id/link_names' => 'publication_names#link_names', as: :link_publication_name
  post 'publications/:id/link_names' => 'publication_names#link_names_commit', as: :link_publication_name_commit
  post 'names/:id/proposed_by' => 'names#proposed_by', as: :name_proposed_by
  get 'names/:id/corrigendum_by' => 'names#corrigendum_by', as: :name_corrigendum_by
  post 'names/:id/corrigendum' => 'names#corrigendum', as: :name_corrigendum
  post 'names/:id/emended_by/:publication_id' => 'names#emended_by', as: :name_emended_by
  get 'names/:id/edit_etymology' => 'names#edit_etymology', as: :edit_name_etymology
  get 'names/:id/edit_notes' => 'names#edit_notes', as: :edit_name_notes
  get 'names/:id/edit_rank' => 'names#edit_rank', as: :edit_name_rank
  get 'names/:id/edit_links' => 'names#edit_links', as: :edit_name_links
  get 'names/:id/link_parent' => 'names#link_parent', as: :name_link_parent
  get 'names/:id/type' => 'names#edit_type', as: :edit_name_type
  post 'names/:id/link_parent' => 'names#link_parent_commit', as: :name_link_parent_commit
  post 'names/:id/submit' => 'names#submit', as: :submit_name
  post 'names/:id/return' => 'names#return', as: :return_name
  post 'names/:id/validate' => 'names#validate', as: :validate_name
  post 'names/:id/claim' => 'names#claim', as: :claim_name
  resources :publications
  resources :subjects

  # Helpers
  get 'autocomplete_names.json' => 'names#autocomplete', as: :autocomplete_names
end
