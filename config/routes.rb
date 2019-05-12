Rails.application.routes.draw do
  root to: 'application#main'
  get 'search' => 'application#search', as: :search
  resources :publication_names
  resources :names
  resources :authors
  resources :publications
  resources :subjects
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
