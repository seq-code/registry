Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  get 'sysusers' => 'users#index(.:format)', as: :users
  get 'sysusers/:username(.:format)' => 'users#show', as: :user
  get 'dashboard' => 'users#dashboard', as: :dashboard
  get 'contributors' => 'users#contributor_request', as: :contributor_request
  post 'contributors' => 'users#contributor_apply', as: :contributor_apply
  post 'contributors/grant/:username' => 'users#contributor_grant', as: :contributor_grant
  post 'contributors/deny/:username' => 'users#contributor_deny', as: :contributor_deny
  root to: 'application#main'
  get 'search' => 'application#search', as: :search
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
  get 'names/:id/link_parent' => 'names#link_parent', as: :name_link_parent
  post 'names/:id/link_parent' => 'names#link_parent_commit', as: :name_link_parent_commit
  resources :publications
  resources :subjects
end
