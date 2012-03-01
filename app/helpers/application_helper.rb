module ApplicationHelper
  def captcha_tags
    recaptcha_tags :public_key => Configurable[:recaptcha_public]
  end

  def view_settings_path
    current_user ? presentations_path : edit_local_presentations_path
  end
end
