require 'test_helper'

class ApiControllerTest < ActionController::TestCase
  test "should get commit_activity" do
    get :commit_activity
    assert_response :success
  end

  test "should get import" do
    get :import
    assert_response :success
  end

end
