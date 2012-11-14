class FasterPost < ActiveRecord::Base
  # Fast access attrs.  Refer to Posts class to understand what they should mean.
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

  set_table_name :posts

  # Optimizations
  # unless we read raw attributes, we spend too much time looking for them in association caches, etc.
  # This made the rendering 30% faster.
  %w(title unreg_name user_login author_id empty_body parent_id created_at hide_action body body_filter cache_timestamp follow rating score).each {|m| send :define_method, m.to_sym do
    read_attribute_before_type_cast(m)
  end}

  def initialize(ats = {})
    ats.each do |k,v|
      send("#{k}=",v)
    end
  end

  def cssid
    author_id
  end

  def empty_body?
    # ActiveRecord should do this, but we're optimizing
    raw = empty_body
    empty_body && empty_body != 0
  end

  def deleted
    read_attribute_before_type_cast('deleted') == 1
  end

  def parent_value
    parent_id.nil?? nil : parent_id
  end

  def hidden_by?(opts = {})
    Posts.hidden_by?(id,hide_action,opts)
  end

  # Since YAML is stateless, we may cache the records we load
  # Returns frozen records.  Duplicate them if you want.
  class CachingYaml
    @@load_cache = {}
    def load(str)
      return str unless str.is_a?(String) && str =~ /^---/
      if rs = @@load_cache[str]; return rs; end
      begin
        loc = @@load_cache[str] = YAML.load(str).freeze
      rescue
        loc = @@load_cache[str] = nil
      end
    end

    # Caching for serialized values is not that important, as massive posting is not what we optimize for
    def dump(obj)
      YAML.dump(obj)
    end
  end

  # I'm not sure if it's documented, but we can specify a loader object here instead of the object's class name
  # NOTE: this setting has no effect, and is superseded by that of Posts.
  serialize :marks, CachingYaml.new
  # However, if they are unset, we should show the user an array
  def marks
    _read_attribute(:marks) || []
  end

  def clicks
    # NOTE: the attribute to read_attribute_before_type_cast should be a string, not a sym.  Otherwise they don't work as expected.
    raw = read_attribute_before_type_cast('clicks')
    raw.blank? ? 0 : raw
  end

  def rating
    raw = read_attribute_before_type_cast('rating')
    raw.blank? ? 0 : raw
  end

  def score
    raw = read_attribute_before_type_cast('score')
    raw.blank? ? 0 : raw
  end

  # Override inspect, as ActiveRecord's inspect wants fields, and we do not have them.
  def inspect
    Object.instance_method(:inspect).bind(self).call
  end

  # If a body and a body_filter are present, filter it!
  def filtered_body
    TextContainer.filter_cached(body,body_filter.to_sym,id,1,cache_timestamp)
  end

  # Depending on the style of the underlying container, it's either a simple title, or raw title if the underlying container type is html
  def htmlsafe_title
    case body_filter.to_sym
    when :html
      title.html_safe
    else
      ERB::Util.h(title)
    end
  end

  def self.sql_posts(hidden_user_id = nil)
    FasterPost.
      joins('JOIN text_containers on posts.text_container_id = text_containers.id').
      joins('JOIN text_items on (text_items.text_container_id = text_containers.id) and (text_items.revision = text_containers.current_revision)').
      joins('LEFT JOIN users on posts.user_id = users.id').
      joins('LEFT JOIN clicks on clicks.post_id = posts.id').
      joins("LEFT JOIN hidden_posts_users on hidden_posts_users.user_id = #{hidden_user_id || 'NULL'} AND hidden_posts_users.posts_id = posts.id").
      joins("LEFT JOIN like_users on like_users.user_id = #{hidden_user_id || 'NULL'} AND like_users.posts_id = posts.id").
      select('posts.id, posts.parent_id, posts.thread_id').
      select('text_containers.filter as body_filter, text_containers.updated_at as cache_timestamp').
      select('text_items.body as title').where('text_items.number = 0').
      select('posts.empty_body, posts.follow, posts.marks, posts.unreg_name, posts.host, posts.created_at').
      select('users.login as user_login').
      select('users.id as author_id').
      select('clicks.clicks, hidden_posts_users.action as hide_action').
      select('rating').
      select('like_users.score as score').
      select('deleted')
  end

  def self.latest(length,settings_for,load_deleted = true,bodies = false)
    la = sql_posts(settings_for ? settings_for.id : nil).
      where(['(not deleted) or ?', load_deleted]).
      order('posts.created_at desc')

    if bodies
      la = la.
        joins('JOIN text_items as bodies on (bodies.text_container_id = text_containers.id) and (bodies.revision = text_containers.current_revision) and (bodies.number = 1)').
        select('bodies.body as body')
    end

    la.first(length)
  end


  # TODO: Add loading actual Post on method_missing!  It will become a fully transparent proxy object then!

end

