Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  get 'sysusers' => 'users#index(.:format)', as: :users
  get 'sysusers/:username(.:format)' => 'users#show', as: :user
  get 'dashboard' => 'users#dashboard', as: :dashboard
  get 'contributor' => 'users#contributor_request', as: :contributor_request
  post 'contributor' => 'users#contributor_apply', as: :contributor_apply
  post 'contributor/grant/:username' => 'users#contributor_grant', as: :contributor_grant
  post 'contributor/deny/:username' => 'users#contributor_deny', as: :contributor_deny
  root to: 'application#main'
  get 'search' => 'application#search', as: :search
  resources :names
  resources :authors
  resources :publication_names
  get 'doi/:doi' => 'publications#show', as: :doi, doi: /.+/
  get 'publication/:id/link_names' => 'publication_names#link_names', as: :link_publication_name
  post 'publication/:id/link_names' => 'publication_names#link_names_commit', as: :link_publication_name_commit
  post 'name/:id/proposed_by' => 'names#proposed_by', as: :name_proposed_by
  post 'name/:id/emended_by/:publication_id' => 'names#emended_by', as: :name_emended_by
  resources :publications
  resources :subjects
end
