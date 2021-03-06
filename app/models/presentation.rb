require 'autoload/utils'
class Presentation < ActiveRecord::Base
  belongs_to :user
  composed_of :tz, :class_name => 'TZInfo::Timezone', :mapping => %w(time_zone time_zone)

  # Mass-assignment protection
  attr_accessible :name, :global, :time_zone, :threadpage_size, :highlight_self, :hide_signatures, :smooth_threshold, :plus, :autowrap_thread_threshold, :autowrap_thread_value, :normal_order

  validates_uniqueness_of :name, :scope => :user_id, :unless => proc {|p| p.user.nil?}
  validates_uniqueness_of :cookie_key, :unless => proc {|p| p.cookie_key.nil?}

  # Returns default presentation
  @@default_presentation = nil
  def self.default
    # We wanted to cache them, but, in production environment, models are not re-loadedd at each request
    Presentation.where('global = true').first || Presentation.new(
                     :name => 'site_global',
                     :global => true,
                     :time_zone => DEFAULT_TZ.name,
                     :threadpage_size => 50,
                     :highlight_self => true,
                     :hide_signatures => false,
                     :smooth_threshold => 10,
                     :plus => true,
                     :normal_order => false,
                     # Updated_at is very important for caching.  It serves as a cache key for all guest users.
                     # The default presentation may change either at server restart or when admin adjusts the configuration.  We account for both, whichever happens last.
                     # We use "compact" since the first value may be nil if there's no presentations yet.
                     :updated_at => [ApplicationController.config_updated_at,DEFAULT_PRESENTATION_MTIME].compact.max
                    )
  end

  # Clone a presentation
  alias_method :activerecord_clone, :clone
  def clone
    new_one = self.dup
    new_one.name = unique_name
    new_one
  end

  # Set this presentation as default
  def make_default
    user.default_presentation = self
    user.save(:validate => false)
  end

  # Set this presentation as current
  def use(cookies)
    cookies[:presentation_name] = { :value => self.name, :expires => VIEW_EXPIRATION_TIME.from_now }
  end

  # Saves this as a local view to the cookies supplied.  Will delete old presentations that belong to the given IP address.
  def record_into(cookies, origin_ip = nil)
    generate_cookie_key
    self.requested_by = origin_ip
    cookies[:presentation_key] = { :value => self.cookie_key, :expires => VIEW_EXPIRATION_TIME.from_now }
    self
  end

  # Loads the presentation from cookies
  def self.from_cookies(cookies)
    key = cookies[:presentation_key]
    # If nothing is recorded in cookies, then there's no presentation
    return nil unless key
    # Global presentation has cookie_key and user_id equal to nil, but global is "true" for it.
    if r = Presentation.find_last_by_cookie_key_and_user_id_and_global(key,nil,false)
      # Technically, we need to update access time each time we load the presentation.  This would exhibit high load on the server.
      # Instead, we update only in 1% of accesses.
      if rand < (1.0/UPDATE_VIEW_ACCESS_TIME_PER)
        r.accessed_at = Time.now
        r.save
      end
      r
    else
      # Cookies don't contain a valid presentation index, return nothing.  We'll get to the default presentation via controller's current_presentation
      nil
    end
  end

  # Attaches the local view to the user, generating a name, if necessary
  def attach_to(target_user)
    self.cookie_key = nil
    self.user = target_user
    if target_user && target_user.presentations.where(['name = ?', self.name]).first
      self.name = unique_name('local')
    end
    save
  end

  private
  # Generate a name that's not already been taken
  # NOTE that there's an obiovus race condition: a unique name may be already taken at the point of creation, but it's scoped to the user, so we leave it to him or her
  def unique_name(base = 'view')
    # This may be called when we're dupping the default global presentation for a cookie key.  Then, we don't have a user, and will never have
    return name unless self.user
    # Ok, we're dupping one of the user's presentation
    user_has = self.user.presentations.length
    while self.user.presentations.where(['name = ?', "#{base}#{user_has}"]).first
      user_has += 1
    end
    "#{base}#{user_has}"
  end

  # Generate cookie_key: a key for this presentation for user cookies.  This can't be ID, as other users should not know them
  def generate_cookie_key
    begin
      key = "ck_#{generate_random_string(35, '0123456789abcdef')}"
    end until not Presentation.find_by_cookie_key(key)
    self.cookie_key = key
  end

  # Remove old presentations for this IP address
  KEEP_FOR_IP = 5
  scope :cookie_based, where(:global => false, :user_id => nil)
  after_create do
    # Not removing Presentations with NULL requestors maintains backward compatibility!
    unless requested_by.blank?
      # Get access time for the "worst" presentation
      threshold_access_time = Presentation.cookie_based.where(:requested_by => requested_by).where('accessed_at is not NULL').order('accessed_at DESC').first(KEEP_FOR_IP).map(&:accessed_at).compact.min
      Presentation.cookie_based.where(:requested_by => requested_by).where(['accessed_at is NULL OR accessed_at < ?', threshold_access_time]).delete_all
    end
  end
  # The protection requires a correctly set accessed_at...
  before_save do
    self.accessed_at ||= Time.now
    true
  end
end
