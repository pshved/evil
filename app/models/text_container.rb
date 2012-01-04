class TextContainer < ActiveRecord::Base
  has_many :text_items

  # Returns the body for the last revision
  def body
    if current_revision
      self.text_items.where(["revision = ?", current_revision]).order('number ASC').map &:body
    else
      nil
    end
    #self.text_items.order('revision DESC').first
  end

  def add_revision(*texts)
    # Check if the arity matches
    raise "Arity #{arity} doesn't match the length of the supplied array: #{texts.inspect}" if texts.length != arity

    # We need a safe way in case there'll be two concurrent updates; we should get revision numbers right
    transaction do
      cur_rev = current_revision || 0
      new_rev = cur_rev + 1
      # Create kids
      texts.each_with_index {|txt,i| text_items.create(:number => i, :body => txt, :revision => new_rev)}
      # Update revision
      self.current_revision = new_rev
      self.save
    end
  end
end
