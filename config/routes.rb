# frozen_string_literal: true

Rails.application.routes.draw do
  scope '(:locale)', locale: /en|fr/ do
    root to: 'pages#home'

    # Sessions & registrations
    resource :session, only: %i[new create destroy]
    resources :registrations, only: %i[new create]
    # Helper used by UI (home page links)
    get  'sign_up', to: 'registrations#new',   as: :sign_up
    post 'sign_up', to: 'registrations#create'

    # Password reset
    resources :passwords, only: %i[new create edit update], param: :token

    # Elo
    get 'elo', to: 'elo#index', as: :elo

    # Dashboard
    resource :dashboard, only: :show

    # Game events
    namespace :game do
      resources :events, only: %i[new create]
    end

    # Users search (used by player search UI)
    get 'users/search', to: 'users#search', as: :users_search
    resources :users, only: %i[index]

    # Tournaments
    resources :tournaments do
      member do
        post :register
        delete :unregister
        post :check_in
        post :lock_registration
        post :next_round
        post :finalize
      end

      namespace :tournament do
        resources :rounds, only: %i[index show]
        resources :matches, only: %i[index show update new create]
      end
    end
  end
end
