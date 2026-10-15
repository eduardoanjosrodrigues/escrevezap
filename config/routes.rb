Rails.application.routes.draw do
  root "pages#home"
  get  "precos",             to: "pages#pricing",        as: :pricing
  get  "privacidade",        to: "pages#privacidade",    as: :privacidade
  get  "termos",             to: "pages#termos",         as: :termos
  get  "transcrever-audio",  to: "pages#free_tool",      as: :free_tool
  post "testar-transcricao", to: "pages#try_transcribe", as: :try_transcribe

  # ── SEO ────────────────────────────────────────────────────────────
  # Dynamic robots.txt + sitemap.xml + programmatic SEO landings.
  get "robots.txt",  to: "seo#robots",  defaults: { format: "text" }
  get "sitemap.xml", to: "seo#sitemap", defaults: { format: "xml" }
  get "llms.txt",    to: "seo#llms",    defaults: { format: "text" }

  # Páginas que disputavam a mesma busca com outra; 301 para a que fica.
  get "transcrever-audio-whatsapp",              to: redirect("/", status: 301)
  get "blog/transcricao-whatsapp-vs-escrevezap", to: redirect("/escrevezap-vs-transcricao-whatsapp", status: 301)

  # Programmatic SEO landings — slug must exist in SeoPagesController::PAGES.
  # Regex kept inline to avoid autoload coupling at route-load time.
  get "/:slug", to: "seo_pages#show", as: :seo_page,
                constraints: { slug: /converter-audio-em-texto|responder-audio-whatsapp|audio-whatsapp-texto|como-transcrever-audio-de-cliente|como-transcrever-audio-de-reuniao|como-transcrever-audio-de-corretor|como-transcrever-audio-de-advogado|como-transcrever-audio-de-medico|como-transcrever-audio-de-professor|escrevezap-vs-transcricao-whatsapp|transcricao-whatsapp-nao-funciona|transcricao-whatsapp-web/ }

  namespace :blog do
    get "/", to: "posts#index", as: :index
    get "/:slug", to: "posts#show", as: :post
  end

  get  "up"             => "rails/health#show",        as: :rails_health_check
  get  "manifest"       => "pwa#manifest",              as: :pwa_manifest, defaults: { format: :json }
  get  "service-worker" => "pwa#service_worker",        as: :pwa_service_worker, defaults: { format: :js }
  get  "offline"        => "pwa#offline",               as: :pwa_offline, defaults: { format: :html }

  mount SolidQueueDashboard::Engine, at: "/jobs"

  scope "/app" do
    devise_for :users,
               controllers: {
                 sessions:           "users/sessions",
                 omniauth_callbacks: "users/omniauth_callbacks"
               },
               skip: [ :passwords, :registrations ]

    devise_scope :user do
      get    "entrar",                    to: "users/sessions#new",        as: :new_user_session
      post   "entrar",                    to: "users/sessions#create"
      delete "sair",                      to: "users/sessions#destroy",    as: :destroy_user_session
      get    "entrar/verificar/:token",   to: "users/sessions#magic_link", as: :magic_link
      get    "entrar/confirmar",          to: "users/sessions#check_inbox", as: :check_inbox
    end

    authenticated :user do
      root "dashboard#index", as: :authenticated_root

      # Onboarding (first-time WhatsApp connection — auth layout, no app chrome)
      get  "conectar",          to: "onboarding#show",             as: :onboarding
      post "conectar/reconectar", to: "onboarding#reconnect",      as: :onboarding_reconnect
      post "conectar/pular",    to: "onboarding#skip_connection",  as: :onboarding_skip_connection

      # WhatsApp connection
      resource :waha_session,        only: [ :show, :create, :destroy ], as: :app_waha_session do
        member do
          get  :qr
          get  :status
          post :pairing_code
          post :reconnect
        end
      end

      # Contacts to monitor for transcription
      resources :monitored_contacts, only: [ :index, :new, :create, :edit, :update, :destroy ] do
        collection do
          get  :whatsapp_contacts
          post :switch_mode
        end
      end

      # User profile
      resource :profile, controller: "profile", only: [ :show, :update ] do
        patch :update_email, on: :member
      end


      # Billing / upgrade flow
      scope "/assinatura" do
        get    "",               to: "billing#show",         as: :billing
        post   "upgrade",        to: "billing#upgrade",       as: :billing_upgrade
        post   "trocar-plano",            to: "billing#change_plan",         as: :billing_change_plan
        get    "trocar-plano/confirmar",    to: "billing#change_plan_confirm",  as: :billing_change_plan_confirm
        get    "cancelar",                 to: "billing#cancel_confirm",       as: :billing_cancel_confirm
        delete "cancelar",       to: "billing#cancel",        as: :billing_cancel
        get    "obrigado",       to: "billing#success",       as: :billing_success
      end
    end
  end

  namespace :admin do
    root "dashboard#index"
    resources :users,                only: [ :index, :show ] do
      resources :whatsapp_messages, only: [ :index ], module: :users
    end
    resources :transcriptions,       only: [ :index, :show ]
    resources :transcription_errors, only: [ :index ]
    resources :waha_sessions,        only: [ :edit, :update ]
  end

  namespace :webhook do
    resource :waha,       only: [ :create ], controller: :waha
    resource :abacate_pay, only: [ :create ], controller: :abacate_pay
    resource :inter,      only: [ :create ], controller: :inter

    get "meta", to: "meta#index"
    post "meta", to: "meta#create"
  end

  # Catch-all 404 — must be the LAST route.
  # Excludes /rails/*, /assets/*, and static files served by the web server.
  match "*unmatched", to: "errors#not_found", via: :all,
        constraints: ->(req) {
          !req.path.start_with?("/rails/") &&
          !req.path.start_with?("/assets/") &&
          !req.path.include?("/auth/") &&
          req.path !~ /\.(png|jpg|jpeg|gif|svg|ico|webp|css|js|map|woff2?|ttf|eot)(\z|\?)/i
        }
end
