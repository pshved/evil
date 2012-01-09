authorization do
  role :guest do
    # Remove :create here if you don't want unregs to create threads
    # TODO : appconfig
    # TODO : web interface?
    has_permission_on :threads, :to => [:read, :create]
    # Anonymous may create posts
    has_permission_on :loginposts, :to => :create do
      if_attribute :user => is { nil }
    end
  end

  role :banned do
    # We do not include guest, as a banened user may have even less rights than a guest
    #includes :guest
    has_permission_on :threads, :to => :read
  end

  role :user do
    includes :guest
    includes :banned
    has_permission_on :threads, :to => :manage

    # This is a functionality to create posts
    # TODO: add reply_to param checking
    has_permission_on :loginposts, :to => :create do
      if_attribute :user => is { user }
    end
  end

  role :moderator do
    includes :user
    has_permission_on :threads, :to => :manage
  end

  role :admin do
    includes :moderator
    has_permission_on :threads, :to => :manage
  end
end

privileges do
  # default privilege hierarchies to facilitate RESTful Rails apps
  privilege :manage, :includes => [:create, :read, :update, :delete]
  privilege :view, :includes => [:read, :show]
  privilege :list, :includes => [:view, :index]
  privilege :create, :includes => :new
  privilege :update, :includes => :edit
  privilege :delete, :includes => :destroy
end
