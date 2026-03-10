Rails.application.routes.draw do
  post "player/play", to: "player#play", as: "play"
  root "pages#home"

  get "up" => "rails/health#show", as: :rails_health_check
end
