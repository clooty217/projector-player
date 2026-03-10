Rails.application.routes.draw do
  root "pages#home"

  scope :tmdb do
    get "trending", to: "tmdb#trending"
    get "search",   to: "tmdb#search"
    get "movie/:id", to: "tmdb#movie", as: :tmdb_movie
    get "tv/:id",    to: "tmdb#tv", as: :tmdb_tv
    get "tv/:id/season/:season", to: "tmdb#season", as: :tmdb_season
  end

  post "player/play",        to: "player#play",        as: :play
  post "player/pause",       to: "player#pause",       as: :pause
  post "player/resume",      to: "player#resume",      as: :resume
  post "player/volume_up",   to: "player#volume_up",   as: :volume_up
  post "player/volume_down", to: "player#volume_down",  as: :volume_down
  post "player/seek_forward",     to: "player#seek_forward",     as: :seek_forward
  post "player/seek_backward",    to: "player#seek_backward",    as: :seek_backward
  post "player/seek_forward_60",  to: "player#seek_forward_60",  as: :seek_forward_60
  post "player/seek_backward_60", to: "player#seek_backward_60", as: :seek_backward_60
  post "player/restart",          to: "player#restart",           as: :restart
  post "player/force_hd",        to: "player#force_hd",          as: :force_hd
  post "player/exit",        to: "player#exit_player",  as: :exit_player
  get  "player/status",      to: "player#status",       as: :player_status

  scope :audio do
    get  "sinks",    to: "audio#sinks"
    post "set_sink", to: "audio#set_sink", as: :audio_set_sink
  end

  get  "player/volume",  to: "player#volume", as: :player_volume

  scope :bluetooth do
    get  "devices",    to: "bluetooth#devices"
    post "scan",       to: "bluetooth#scan"
    post "connect",    to: "bluetooth#connect",    as: :bt_connect
    post "disconnect", to: "bluetooth#disconnect", as: :bt_disconnect
    post "remove",     to: "bluetooth#remove",     as: :bt_remove
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
