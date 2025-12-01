Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  devise_scope :user do
    match '/users/auth/failure', to: 'users/omniauth_callbacks#failure', via: [ :get, :post ]
  end

  # Authenticated users see the posts feed
  authenticated :user do
    root 'posts#index', as: :authenticated_root
  end

  # Unauthenticated users see the login page
  unauthenticated do
    devise_scope :user do
      root 'devise/sessions#new', as: :unauthenticated_root
    end
  end

  # Moderation namespace for staff/moderator actions
  namespace :moderation do
    resources :posts, only: [ :index, :show ] do
      member do
        patch :redact
        patch :unredact
      end
    end

    resources :answers, only: [ :show ] do
      member do
        patch :redact
        patch :unredact
      end
    end
  end

  resources :posts do
    member do
      patch :reveal_identity
      patch :hide_identity
      patch :unlock
      post :appeal
      post :bookmark
      delete :unbookmark
    end
    collection do
      post :preview
      get :my_threads
      get :bookmarked
    end

    post 'upvote', to: 'likes#upvote', on: :member
    post 'downvote', to: 'likes#downvote', on: :member

    resources :answers, only: [ :create, :destroy, :edit, :update ] do
      member do
        patch :reveal_identity
        patch :accept
      end

      resources :comments, only: [ :create, :destroy ], controller: 'answer_comments'
    end

    resources :likes, only: [ :create, :destroy ]
  end

  # Default root path helper
  root 'posts#index'
end
