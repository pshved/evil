module PostValidators
  # Include all validations here
  def validates_post_attrs
    validates_length_of :title, :maximum => 100
  end
end
