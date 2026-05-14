Rails.application.routes.draw do
  mount ActionCable.server => '/cable'

  resources :tags
  # General configuration
  root(to: 'application#main')
  concern(:autocompletable) do
    get  :autocomplete, on: :collection
  end

  # Static pages
  namespace :page do
    %i[
      api about committee connect help initiative issues join
      news prize publications seqcode linkout status
      sandbox stats videos
    ].each { |i| get(i) }
  end
  get  'help' => 'page#help_index', as: :help_index
  get  'help/:topic' => 'page#help', as: :help

  # Users
  get  'sysusers(.:format)' => 'users#index', as: :users
  get  'sysusers/:username(.:format)' => 'users#show', as: :user
  post 'sysusers/:username(.:format)' => 'users#update'
  get  'dashboard' => 'users#dashboard', as: :dashboard
  get  'contributors' => 'users#contributor_request', as: :contributor_request
  post 'contributors' => 'users#contributor_apply', as: :contributor_apply
  post 'contributors/grant/:username' => 'users#contributor_grant', as: :contributor_grant
  post 'contributors/deny/:username' => 'users#contributor_deny', as: :contributor_deny
  get  'curators' => 'users#curator_request', as: :curator_request
  post 'curators' => 'users#curator_apply', as: :curator_apply
  post 'curators/grant/:username' => 'users#curator_grant', as: :curator_grant
  post 'curators/deny/:username' => 'users#curator_deny', as: :curator_deny
  devise_for(:users, controllers: { registrations: 'users/registrations' })

  # Alerts (Notifications)
  resources(
    :notifications, path: 'alerts',
    only: %i[index show update destroy]
  ) do
    collection do
      post :all_seen
      post :all_destroy
    end
    member do
      post :toggle_seen
    end
  end

  # Names
  # --> Standard resources
  resources(:names, controller: 'names/main') do
    collection do
      # --> Index
      get  :type_genomes, controller: 'names/filtering'
      # --> Filtering
      get  :submitted, controller: 'names/filtering'
      get  :endorsed, controller: 'names/filtering'
      get  :draft, controller: 'names/filtering'
      get  :user, controller: 'names/filtering'
      get  :observing, controller: 'names/filtering'
      get  :linkout, controller: 'names/utility'
      # --> User utilities
      get  :autocomplete, controller: 'names/utility'
      get  :etymology_sandbox, controller: 'names/utility'
      get  :syllabify, controller: 'names/utility'
      # --> Curator utilities
      get  :unranked, controller: 'names/filtering'
      get  :unknown_proposal, controller: 'names/filtering'
    end
    member do
      # --> Display name
      get  :network, controller: 'names/network'
      get  :linkout, controller: 'names/utility'
      get  :wiki, controller: 'names/wiki'
      get  :quality_checks, controller: 'names/utility'
      # --> Edit name
      get  :edit_description, controller: 'names/editing'
      get  :edit_type, controller: 'names/editing'
      get  :edit_etymology, controller: 'names/editing'
      get  :autofill_etymology, controller: 'names/editing'
      get  :edit_notes, controller: 'names/editing'
      get  :edit_rank, controller: 'names/editing'
      get  :edit_links, controller: 'names/editing'
      get  :edit_redirect, controller: 'names/editing'
      post :return, controller: 'names/status'
      post :validate, controller: 'names/status'
      post :endorse, controller: 'names/status'
      post :temporary_editable, controller: 'names/status'
      # --> Edit user relationship to name
      get  :observe, controller: 'names/user_actions'
      get  :unobserve, controller: 'names/user_actions'
      post :claim, controller: 'names/status'
      post :unclaim, controller: 'names/status'
      post :demote, controller: 'names/status'
      get  :transfer_user, controller: 'names/user_actions'
      post :transfer_user, action: :transfer_user_commit, controller: 'names/user_actions'
      # --> Edit name relationships
      get  :edit_parent, controller: 'names/editing'
      post :new_correspondence, controller: 'names/user_actions'
      post :proposed_in, path: '/proposed_in/:publication_id', controller: 'names/publications'
      get  :corrigendum_in, controller: 'names/publications'
      post :corrigendum, controller: 'names/publications'
      post :emended_in, path: '/emended_in/:publication_id', controller: 'names/publications'
      post :assigned_in, path: '/assigned_in/:publication_id', controller: 'names/publications'
      post :not_validly_proposed_in,
           path: '/not_validly_proposed_in/:publication_id', controller: 'names/publications'
    end
    resources :pseudonyms
  end

  # Taxonomic placements
  resources(:placements, only: %i[create edit update destroy]) do
    post :prefer, on: :member
  end
  get '/placements/new/:name_id', controller: :placements, action: :new, as: :new_placement

  # Genomes
  resources(:genomes) do
    member do
      post  :update_external
      post  :recalculate_miga
      patch :update_accession
      get   :sample_map
    end
  end

  # Strains
  resources(:strains, only: %i[index show]) do
    member do
      get  :strain_info
      get  :link_genome
      post :link_genome_commit
      post :unlink_genome
    end
  end

  # Checks
  post 'check/:name_id(.:format)' => 'checks#update', as: :check

  # Register lists
  # --> Standard resources
  resources(:registers, param: :accession) do
    collection do
      get  :map
    end
    member do
      # --> Display
      get  :table
      get  :list
      get  :cite
      get  :certificate_image
      get  :sample_map
      get  :tree
      get  :reviewer_token
      post :reviewer_token, action: :reviewer_token_create
      delete :reviewer_token, action: :reviewer_token_delete
      # --> Register edit
      post :submit
      get  :return
      post :return, action: :return_commit
      post :endorse
      get  :notify
      post :notify, action: :notify_commit
      get  :prenotify
      post :prenotify, action: :prenotify_commit
      post :validate
      get  :editorial_checks
      get  :publish
      post :publish, action: :publish_commit
      patch :internal_notes
      post :nomenclature_review
      post :genomics_review
      get  :merge
      post :merge, action: :merge_commit
      get  :coauthors
      post :coauthors, action: :coauthors_commit
      get  :transfer_user
      post :transfer_user, action: :transfer_user_commit
      # --> Special curation pages
      get  :curation_genomics
      post :snooze_curation
      post :recheck_pdf_files
      # --> Edit user relationship to register list
      get  :observe
      get  :unobserve
      # --> Edit register relationships
      post :new_correspondence
    end
  end

  # Authors
  resources(:authors, concerns: :autocompletable)

  # Journals
  resources(:journals, only: %i[index show], param: :journal)

  # Publications
  resources(:publications, concerns: :autocompletable) do
    resources(:contacts, only: %i[new create show index])
    member do
      get  :names
    end
  end
  get  'doi/:doi' => 'publications#show', as: :doi, doi: /.+/
  resources(:contacts, only: []) do
    collection do
      get  :user
    end
  end

  # Publication Names (n:m relationship)
  get  'publications/:id/link_name' => 'publication_names#link_name', as: :link_publication_name
  post 'publications/:id/link_name' => 'publication_names#link_name_commit', as: :link_publication_commit_name

  # Other resources
  resources(:subjects, concerns: :autocompletable)
  resources(:tutorials, :publication_names)
  resources(:correspondences, only: []) do
    collection do
      get  :template
    end
  end
  resources(:curations, only: %i[create update])

  # Reports
  get 'reports/genomes/:id', to: 'reports#genome', as: :reports_genome

  # General Application
  get  'link' => 'application#short_link'
  get  'link/:path(.:format)' => 'application#short_link'
  get  'set/list' => 'application#set_list', as: :set_list
  get  'search' => 'application#search', as: :search
end
