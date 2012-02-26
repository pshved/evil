class Presentation < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :name, :scope => :user_id
  composed_of :tz, :class_name => 'TZInfo::Timezone', :mapping => %w(time_zone time_zone)

  # Returns default presentation
  def self.default
    Presentation.new(:time_zone => DEFAULT_TZ.name,
                     :threadpage_size => Configurable[:default_homepage_threads] || Kaminari.config.default_per_page
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
    cookies[:presentation_name] = self.name
  end

  private
  # Generate a name that's not already been taken
  # NOTE that there's an obiovus race condition: a unique name may be already taken at the point of creation, but it's scoped to the user, so we leave it to him or her
  def unique_name
    user_has = self.user.presentations.length
    while self.user.presentations.where(['name = ?', "view#{user_has}"]).first
      user_has += 1
    end
    "view#{user_has}"
  end
end
