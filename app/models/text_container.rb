require 'markup/boardtags'
require 'markup/html_marks'
class TextContainer < ActiveRecord::Base
  has_many :text_items, :autosave => true

  # This is an enum column handled by plugin.
  validates_columns :filter

  # Returns the body for the last revision
  def body
    _items
  end

  # Filters the string given the context and this container's filtering setting
  def self.filter(txt,filter,context = nil)
    case filter
    when :board
      BoardtagsFilter.filter(txt,:to_body,context)
    when :html
      calculate_marks_for_html(txt,context)
      txt || ''
    end
  end

  # Cached filter
  def self.filter_cached(txt,filter,cache_id,cache_index,cache_key,context = nil)
    Rails.cache.fetch("tc-#{cache_id}[#{cache_index}]+#{cache_key}") do
      filter(txt,filter,context)
    end
  end

  def filter_item(txt,context = nil)
    TextContainer.filter(txt,filter,context)
  end

  def filter_item_cached(txt,index,context = nil)
    if @unsaved_texts
      # There are unsaved items.  We do not cache them!
      TextContainer.filter(txt,filter,context)
    else
      TextContainer.filter_cached(txt,filter,id,index,updated_at,context)
    end
  end

  def filtered(context = nil)
    f = _items
    r = []
    f.each_with_index do |txt,i|
      r << filter_item_cached(txt,i,context)
    end
    r
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

  # A more convenient method to mutate the container
  # NOTE that you can't add [] method as well, because ActiveRecord uses it for something
  def []=(index,val)
    raise "Set up TextContainer before mutation!" if arity.nil?
    raise "Trying to mutate at #{index} when the arity is #{arity}" if arity <= index
    if @unsaved_texts
      # If we have already started the mutation, then we can directly alter the container
      @unsaved_texts[index] = val
    else
      # Start the mutation with the altered container
      new_items = _items.dup
      new_items[index] = val
      _add_revs(false,*new_items)
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
