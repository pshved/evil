require 'markup/boardtags'
class TextContainer < ActiveRecord::Base
  has_many :text_items, :autosave => true

  # This is an enum column handled by plugin.
  validates_columns :filter

  # Returns the body for the last revision
  def body
    _items
  end

  # Filters the string given the context and this container's filtering setting
  def filter_item(txt,context = nil)
    case filter
    when :board
      BoardtagsFilter.filter(txt,:to_body,context)
    when :html
      txt
    end
  end

  def filtered(context = nil)
    f = _items
    f.map do |txt|
      filter_item(txt,context)
    end
  end

  def add_revision(*texts)
    _add_revs(false,*texts)
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

    # If the new revisions are going to be saved, just do it in a concurrent manner
    if need_save
      __add_revs(true,*texts)
    else
      # If the new revisions are not going to be saved, store them locally, and flush at save
      @unsaved_texts = texts.dup
    end
  end

  # Flush the unsaved body, if any
  before_save do
    if @unsaved_texts
      # Do not save: they'll be saved at save (this is a before_save callback!)
      if __add_revs(false,*@unsaved_texts)
        @unsaved_texts = nil
        true
      end
    else
      true
    end
    # Proceed to save ...
  end

  # A transaction that saves records
  protected
  def __add_revs(need_save,*texts)
    # We need a safe way in case there'll be two concurrent updates; we should get revision numbers right
    r = false
    transaction do
      cur_rev = current_revision || 0
      new_rev = cur_rev + 1
      # Create kids
      texts.each_with_index {|txt,i| text_items.new(:number => i, :body => txt, :revision => new_rev)}
      # Update revision
      self.current_revision = new_rev
      r = self.save if need_save
    end
    !need_save || r
  end

  # Override the fetching method for the unsaved records
  protected
  def _items
    @unsaved_texts || text_items.where(["revision = ?", current_revision]).order('number ASC').map(&:body)
  end
end
