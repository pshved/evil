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

  # Optimizations
  # unless we read raw attributes, we spend too much time looking for them in association caches, etc.
  # This made the rendering 30% faster.
  %w(title unreg_name user_login empty_body parent_id created_at hidden body body_filter cache_timestamp).each {|m| send :define_method, m.to_sym do
    read_attribute_before_type_cast(m)
  end}

  def initialize(ats = {})
    ats.each do |k,v|
      send("#{k}=",v)
    end
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
    Posts.hidden_by?(id,hidden,opts)
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

  # Override inspect, as ActiveRecord's inspect wants fields, and we do not have them.
  def inspect
    Object.instance_method(:inspect).bind(self).call
  end

  # If a body and a body_filter are present, filter it!
  def filtered_body
    TextContainer.filter_cached(body,body_filter.to_sym,id,1,cache_timestamp)
  end

  # TODO: make it DRY with Threads model!
  def self.latest(length,settings_for,load_deleted = true)
    FasterPost.find_by_sql(["select posts.id, text_items.body as title, posts.created_at, posts.empty_body, posts.parent_id, posts.marks, posts.unreg_name, users.login as user_login, posts.host, clicks.clicks, hidden_posts_users.posts_id as hidden, body_items.body as body, text_containers.filter as body_filter, text_containers.updated_at as cache_timestamp,
      deleted
    from posts
    join text_containers on posts.text_container_id = text_containers.id
    join text_items on (text_items.text_container_id = text_containers.id) and (text_items.revision = text_containers.current_revision)
    join text_items as body_items on (body_items.text_container_id = text_containers.id) and (body_items.revision = text_containers.current_revision)
    left join users on posts.user_id = users.id
    left join clicks on clicks.post_id = posts.id
    left join hidden_posts_users on hidden_posts_users.user_id = #{settings_for ? settings_for.id : 'NULL'} and hidden_posts_users.posts_id = posts.id
    where text_items.number = 0 and body_items.number = 1
      and ((not deleted) or ?)
    order by posts.created_at desc limit ?", load_deleted, length])
  end


  # TODO: Add loading actual Post on method_missing!  It will become a fully transparent proxy object then!

end

