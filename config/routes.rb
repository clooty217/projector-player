Rails.application.routes.draw do
  root "pages#home"

  scope :tmdb do
    get "trending", to: "tmdb#trending"
    get "search",   to: "tmdb#search"
    get "movie/:id", to: "tmdb#movie", as: :tmdb_movie
    get "tv/:id",    to: "tmdb#tv", as: :tmdb_tv
    get "tv/:id/season/:season", to: "tmdb#season", as: :tmdb_season
  end

  post "player/play",   to: "player#play",   as: :play
  post "player/pause",  to: "player#pause",  as: :pause
  post "player/resume", to: "player#resume", as: :resume

  get "up" => "rails/health#show", as: :rails_health_check
end
