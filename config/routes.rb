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
end
