Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'home#index'

  # Authentication
  devise_for :users

  # Core Resources
  resources :groups do
    member do
      get 'digests'
      get 'questions'
      post 'send_invite'
      post 'toggle_member_status/:member_id', to: 'groups#toggle_member_status', as: 'toggle_member_status'
      post 'migrate_legacy_digests'
    end
    get 'accept_invitation', on: :collection
    resources :members, only: [:show], controller: 'group_members'
    scope module: :groups do
      resources :questions, only: [:show] do
        member do
          post 'vote'
          post 'add_tag'
          delete 'remove_tag'
          delete 'unvote'
        end
      end
    end
    resources :question_digests, only: [:index, :show, :new, :create, :destroy] do
      member do
        post :send_digest
      end
    end
  end
  resources :questions do
    member do
      post 'send', to: 'questions#send_to_group', as: 'send'
    end
  end
  resources :question_records
  resources :answers
  resources :users

  # Custom Actions
  post 'send_random', to: 'questions#send_random_question'
  post 'inbound', to: 'email_response#create_from_inbound_hook'
  post 'answer', to: 'answers#create_from_form'

  # Admin Section
  namespace :admin do
    get 'dashboard', to: 'dashboard#index'

    get 'dashboard/visits', to: 'dashboard#visits'
    get 'dashboard/emails', to: 'dashboard#emails'
    get 'dashboard/events', to: 'dashboard#events'
    get 'dashboard/users', to: 'dashboard#users'
    get 'dashboard/users/:id', to: 'dashboard#user_details', as: 'dashboard_user_details'

    # Chart data endpoints
    get 'dashboard/daily_visits_data', to: 'dashboard#daily_visits_data'
    get 'dashboard/hourly_visits_data', to: 'dashboard#hourly_visits_data'
    get 'dashboard/countries_data', to: 'dashboard#countries_data'
    get 'dashboard/devices_data', to: 'dashboard#devices_data'
    get 'dashboard/emails_data', to: 'dashboard#emails_data'
    get 'dashboard/events_data', to: 'dashboard#events_data'
    get 'dashboard/regions_data', to: 'dashboard#regions_data'
    get 'dashboard/cities_data', to: 'dashboard#cities_data'
    get 'dashboard/user_activity_data', to: 'dashboard#user_activity_data'
    get 'dashboard/group_activity_data', to: 'dashboard#group_activity_data'

    get 'recent_signups', to: 'dashboard#recent_signups'

    get 'dashboard/groups', to: 'dashboard#groups'
    get 'dashboard/group_details/:id', to: 'dashboard#group_details', as: 'group_details'
  end

  # Development Tools
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
