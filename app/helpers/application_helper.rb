module ApplicationHelper
  def captcha_tags
    recaptcha_tags :public_key => Configurable[:recaptcha_public]
  end
end
