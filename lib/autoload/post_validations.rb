module PostValidators
  # Include all validations here
  def validates_post_attrs
    validates_length_of :title, :maximum => 10
  end
end
