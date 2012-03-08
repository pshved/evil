module ApplicationHelper
  def captcha_tags
    recaptcha_tags :public_key => Configurable[:recaptcha_public]
  end

  def view_settings_path
    current_user ? presentations_path : edit_local_presentations_path
  end

  # Helper to create nice user links in a fast manner
  def user_link(user, maybe_unreg = nil)
    if user
      if user == current_user
        haml_tag 'span.post-self',link_to(user.login, user_path(user))
      else
        haml_tag 'span.post-user',link_to(user.login, user_path(user))
      end
    else
      haml_tag 'span.post-unreg',(maybe_unreg || 'NIL')
    end
  end

  # Nice time conversion
  def user_time(time)
    current_presentation.tz.utc_to_local(time).strftime("%d.%m.%Y %H:%M")
  end
end
