require 'markup/boardtags'
class TextContainer < ActiveRecord::Base
  has_many :text_items, :autosave => true

  # Returns the body for the last revision
  def body
    if current_revision
      self.text_items.where(["revision = ?", current_revision]).order('number ASC').map &:body
    else
      nil
    end
    #self.text_items.order('revision DESC').first
  end

  def filtered(context = nil)
    if current_revision
      f = self.text_items.where(["revision = ?", current_revision]).order('number ASC').map(&:body)
      f.map do |txt|
        if context
          BoardtagsFilter.filter(txt,:to_body,context)
        else
          BoardtagsFilter.filter(txt,:to_body)
        end
      end
    else
      nil
    end
  end

  def add_revision(*texts)
    _add_revs(true,*texts)
  end

  def self.make(*texts)
    r = TextContainer.new
    r.arity = texts.length
    r._add_revs(false,*texts)
    r
  end

  def _add_revs(need_save,*texts)
    # Check if the arity matches
    raise "Arity #{arity} doesn't match the length of the supplied array: #{texts.inspect}" if texts.length != arity

    # We need a safe way in case there'll be two concurrent updates; we should get revision numbers right
    transaction do
      cur_rev = current_revision || 0
      new_rev = cur_rev + 1
      # Create kids
      texts.each_with_index {|txt,i| text_items.new(:number => i, :body => txt, :revision => new_rev)}
      # Update revision
      self.current_revision = new_rev
      self.save if need_save#&& !self.new?
    end
  end
end
