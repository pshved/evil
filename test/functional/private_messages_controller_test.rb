require 'test_helper'

class PrivateMessagesControllerTest < ActionController::TestCase
  setup do
    @private_message = private_messages(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:private_messages)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create private_message" do
    assert_difference('PrivateMessage.count') do
      post :create, private_message: @private_message.attributes
    end

    assert_redirected_to private_message_path(assigns(:private_message))
  end

  test "should show private_message" do
    get :show, id: @private_message.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @private_message.to_param
    assert_response :success
  end

  test "should update private_message" do
    put :update, id: @private_message.to_param, private_message: @private_message.attributes
    assert_redirected_to private_message_path(assigns(:private_message))
  end

  test "should destroy private_message" do
    assert_difference('PrivateMessage.count', -1) do
      delete :destroy, id: @private_message.to_param
    end

    assert_redirected_to private_messages_path
  end
end
