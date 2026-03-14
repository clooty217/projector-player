# typed: false

class PlayerController < ApplicationController
  skip_before_action :verify_authenticity_token

  VIDKING_BASE = "https://www.vidking.net/embed"
  CDP_PORT = 9222

  def play
    tmdb_id    = params.require(:tmdb_id)
    media_type = params.require(:media_type)
    season     = params[:season]
    episode    = params[:episode]
    title      = params[:title] || "Unknown"

    url = build_vidking_url(tmdb_id, media_type, season, episode)

    # TODO: Replace with your system call to open the video in Chromium.
    # Make sure to include --remote-debugging-port so pause/volume/exit work:
    #   pid = spawn("chromium-browser", "--remote-debugging-port=#{CDP_PORT}", "--app=#{url}")
    pid = spawn("chromium-browser",
                "--disable-gpu",
                "--remote-debugging-port=9222",
                "--start-fullscreen",
                "--autoplay-policy=no-user-gesture-required",
                "--password-store=basic",
                "--disable-features=LockProfileCookieDatabase",
                "--disable-session-crashed-bubble",
                url)
    Process.detach(pid)

    self.class.current_pid = pid
    self.class.current_title = title

    render json: { status: "playing", url: url, title: title }
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

  def volume_up
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("(() => { const v = document.querySelector('video'); if(v) { v.volume = Math.min(1, v.volume + 0.1); return v.volume; } })()")
    render json: { status: "ok", volume: result.dig("result", "result", "value") }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def volume_down
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("(() => { const v = document.querySelector('video'); if(v) { v.volume = Math.max(0, v.volume - 0.1); return v.volume; } })()")
    render json: { status: "ok", volume: result.dig("result", "result", "value") }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def volume
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("(() => { const v = document.querySelector('video'); if(v) return v.volume; })()")
    render json: { status: "ok", volume: result.dig("result", "result", "value") }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def force_hd
    cdp = CdpClient.new(port: CDP_PORT)
    js = <<~JS.squish
      (() => {
        function findHls() {
          if (typeof Hls === 'undefined') return null;
          if (window.hls && window.hls.levels) return window.hls;
          if (window.player && window.player.hls && window.player.hls.levels) return window.player.hls;
          const video = document.querySelector('video');
          if (video) {
            const keys = Object.getOwnPropertyNames(video);
            for (let i = 0; i < keys.length; i++) {
              try {
                const obj = video[keys[i]];
                if (obj && obj.levels && typeof obj.currentLevel === 'number') return obj;
              } catch(e) {}
            }
          }
          const wkeys = Object.keys(window);
          for (let i = 0; i < wkeys.length; i++) {
            try {
              const obj = window[wkeys[i]];
              if (obj && obj.levels && typeof obj.currentLevel === 'number' && typeof obj.loadLevel === 'number') return obj;
            } catch(e) {}
          }
          return null;
        }
        const hls = findHls();
        if (hls && hls.levels && hls.levels.length > 0) {
          const highest = hls.levels.length - 1;
          hls.currentLevel = highest;
          const h = hls.levels[highest].height;
          return { success: true, quality: h ? h + 'p' : 'max', levels: hls.levels.length };
        }
        return { success: false };
      })()
    JS
    result = cdp.evaluate(js)
    value = result.dig("result", "result", "value") || {}
    render json: { status: "ok", quality: value }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def seek_forward
    seek(10)
  end

  def seek_backward
    seek(-10)
  end

  def seek_forward_60
    seek(60)
  end

  def seek_backward_60
    seek(-60)
  end

  def restart
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("(() => { const v = document.querySelector('video'); if(v) { v.currentTime = 0; return v.currentTime; } })()")
    render json: { status: "ok", result: result }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def exit_player
    pid = self.class.current_pid
    if pid
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        # already exited
      end
      self.class.current_pid = nil
      self.class.current_title = nil
      render json: { status: "exited" }
    else
      render json: { status: "no_process" }
    end
  end

  def status
    render json: {
      playing: self.class.current_pid.present?,
      title: self.class.current_title
    }
  end

  class << self
    attr_accessor :current_pid, :current_title
  end

  private

  def seek(seconds)
    cdp = CdpClient.new(port: CDP_PORT)
    result = cdp.evaluate("(() => { const v = document.querySelector('video'); if(v) { v.currentTime = Math.min(v.duration, Math.max(0, v.currentTime + (#{seconds}))); return v.currentTime; } })()")
    render json: { status: "ok", result: result }
  rescue CdpClient::Error => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end

  def build_vidking_url(tmdb_id, media_type, season, episode)
    base = if media_type == "tv" && season.present? && episode.present?
      "#{VIDKING_BASE}/tv/#{tmdb_id}/#{season}/#{episode}"
    else
      "#{VIDKING_BASE}/movie/#{tmdb_id}"
    end

    "#{base}?autoPlay=true"
  end
end
