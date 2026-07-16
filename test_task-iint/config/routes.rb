Rails.application.routes.draw do
  devise_for :users

  resources :posts

  get 'plans', to: 'pages#plans', as: 'plans'
  root to: 'posts#index'
end
