Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :dashboard, only: [:show], controller: 'dashboard'
  
  get  'sign_up', to: 'registrations#new'
  post 'sign_up', to: 'registrations#create'
  
  root 'pages#home'
end
