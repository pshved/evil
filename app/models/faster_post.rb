class FasterPost < ActiveRecord::Base
  #include ActiveModel::Validations

  # Satisfy the form
  #include ActiveModel::Conversion
  #extend ActiveModel::Naming
  #def persisted? ; false ; end

  # Fast access attrs.  Refer to Posts class to understand what they should mean.
  #attr_accessor :title, :empty, :id, :created_at, :parent_value
  #attr_accessor :parent_value
  @@cc = nil
  @@ch = nil
  def self.columns
    return @@cc if @@cc
    @@cc = Posts.columns
  end
  def self.columns_hash
    return @@ch if @@ch
    @@ch = Posts.columns_hash
  end

  # Optimizations
  # unless we read raw attributes, we spend too much time looking for them in association caches, etc.
  # This made the rendering 30% faster.
  %w(title unreg_name user_login empty_body parent_value created_at).each {|m| send :define_method, m.to_sym do
    read_attribute_before_type_cast(m)
  end}

  def initialize(ats = {})
    ats.each do |k,v|
      send("#{k}=",v)
    end
  end

  def empty_body?
    empty_body
  end

  def parent_value
    parent_id.nil?? nil : parent_id
  end

  # TODO: DRY with Posts!
  serialize :marks
  # However, if they are unset, we should show the user an array
  def marks
    read_attribute(:marks) || []
  end

  # TODO: DRY with Posts
  def clicks
    raw = read_attribute_before_type_cast(:clicks)
    raw.blank? ? 0 : raw
  end

  # Override inspect, as ActiveRecord's inspect wants fields, and we do not have them.
  def inspect
    Object.instance_method(:inspect).bind(self).call
  end

  # TODO: Add loading actual Post on method_missing!  It will become a fully transparent proxy object then!

end

