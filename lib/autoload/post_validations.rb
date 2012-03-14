module PostValidators
  # Include all validations here
  def validates_post_attrs
    validates_length_of :title, :maximum => 100
    validates_presence_of :title
    # Prevent uploading tons of crap
    validates_length_of :body, :maximum => 1_000_000
  end
end
