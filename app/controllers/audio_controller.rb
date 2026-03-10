# typed: false

class AudioController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_service

  def sinks
    render json: serialize(@audio.list_sinks)
  end

  def set_sink
    result = @audio.set_default_sink(params.require(:sink))
    render json: result
  end

  private

  def set_service
    @audio = AudioService.new
  end

  def serialize(sinks)
    sinks.map { |s| { index: s.index, name: s.name, description: s.description, state: s.state, default: s.default } }
  end
end
