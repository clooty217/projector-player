# typed: true

class SystemController < ApplicationController
  skip_before_action :verify_authenticity_token

  def power_off
    render json: { status: "shutting_down" }
    Thread.new { sleep 1; system("sudo shutdown -h now") }
  end
end
