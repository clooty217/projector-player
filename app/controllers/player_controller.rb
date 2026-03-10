# typed: true

class PlayerController < ApplicationController
  skip_before_action :verify_authenticity_token

  VIDKING_BASE = "https://www.vidking.net/embed"
  CDP_PORT = 9222

  def play
    tmdb_id    = params.require(:tmdb_id)
    media_type = params.require(:media_type)
    season     = params[:season]
    episode    = params[:episode]

    url = build_vidking_url(tmdb_id, media_type, season, episode)

    system("chromium --start-fullscreen --autoplay-policy=no-user-gesture-required #{url}")

    render json: { status: "playing", url: url }
  end

  def pause
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("document.querySelector('video').pause()")
    render json: { status: "paused", result: result }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def resume
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("document.querySelector('video').play()")
    render json: { status: "resumed", result: result }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  private

  def build_vidking_url(tmdb_id, media_type, season, episode)
    base = if media_type == "tv" && season.present? && episode.present?
      "#{VIDKING_BASE}/tv/#{tmdb_id}/#{season}/#{episode}"
    else
      "#{VIDKING_BASE}/movie/#{tmdb_id}"
    end

    "#{base}?autoPlay=true"
  end
end
