module PostValidators
  # Include all validations here
  def validates_post_attrs
    validates_length_of :title, :maximum => 100, :if => proc {|p| (! p.respond_to?(:text_container)) || (p.text_container.filter == :board) }
    validates_presence_of :title
    # Prevent uploading tons of crap
    validates_length_of :body, :maximum => 1_000_000
  end
end
