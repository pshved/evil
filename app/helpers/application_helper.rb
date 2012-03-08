module ApplicationHelper
  def captcha_tags
    recaptcha_tags :public_key => Configurable[:recaptcha_public]
  end

  def view_settings_path
    current_user ? presentations_path : edit_local_presentations_path
  end

  # Helper to create nice user links in a fast manner
  def user_link(user)
    link_to user.login, user_path(user)
  end

  # Nice time conversion
  def user_time(time)
    current_presentation.tz.utc_to_local(time).strftime("%d.%m.%Y %H:%M")
  end
end
