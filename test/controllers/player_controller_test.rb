require "test_helper"

class PlayerControllerTest < ActionDispatch::IntegrationTest
  test "should get play" do
    get player_play_url
    assert_response :success
  end
end
