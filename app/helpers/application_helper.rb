module ApplicationHelper
  def captcha_tags
    recaptcha_tags :public_key => config_param(:recaptcha_public)
  end

  def view_settings_path
    current_user ? presentations_path : edit_local_presentations_path
  end

  # Helper to create nice user links in a fast manner
  def user_link(user, maybe_unreg = nil)
    if user
      if user == current_user
        haml_tag 'span.user-self',link_to(user.login, user_path(user))
      else
        haml_tag 'span.user-other',link_to(user.login, user_path(user))
      end
    else
      haml_tag 'span.user-unreg',(maybe_unreg || 'NIL')
    end
  end

  # Nice time conversion
  def user_time(time)
    current_presentation.tz.utc_to_local(time).strftime("%d.%m.%Y %H:%M")
  end

  # Restore good ol' error messages.  Model is a lowercase string.
  # TODO: join several error objects
  def error_messages_for(error_object, model)
    capture_haml(error_object, model) do |error_object, model|
      if error_object.any?
        haml_tag 'div#error_explanation' do
          # We don't know if it's an activerecord or a 
          model_trd = I18n.t("activerecord.models.#{model}", :defaults => "activemodel.models.#{model}").humanize
          haml_tag 'h2',t('activerecord.errors.template.header', :count => error_object.count, :model => model_trd)
          haml_tag 'ul' do
            error_object.full_messages.each do |msg|
              haml_tag 'li',msg
            end
          end
        end
      end
    end
  end

  # Translate model attribute
  def ta(attrib,model,options = {})
    I18n.t("activerecord.attributes.#{model}.#{attrib}",{:defaults => "activemodel.attributes.#{model}.#{attrib}"}.merge(options))
  end
end
