Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :groups

  resources :questions

  devise_for :users
  root to: 'home#index'
  resources :users

  resources :question_records

  resources :answers

  post 'invite' => 'groups#send_invite'
  post 'send_random' => 'questions#send_random_question'
  post 'inbound' => 'email_response#create_from_inbound_hook'
  post 'answer' => 'answers#create_from_form'

  namespace :admin do
    get 'dashboard', to: 'dashboard#index'

    # Chart data endpoints
    get 'dashboard/daily_visits_data', to: 'dashboard#daily_visits_data'
    get 'dashboard/hourly_visits_data', to: 'dashboard#hourly_visits_data'
    get 'dashboard/countries_data', to: 'dashboard#countries_data'
    get 'dashboard/devices_data', to: 'dashboard#devices_data'
    get 'dashboard/emails_data', to: 'dashboard#emails_data'
    get 'dashboard/events_data', to: 'dashboard#events_data'
  end
end
