class PlayerController < ApplicationController
  skip_before_action :verify_authenticity_token
  def play
  end
end
