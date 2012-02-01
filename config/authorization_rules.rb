authorization do
  role :guest do
    # Remove :create here if you don't want unregs to create threads
    # TODO : appconfig
    # TODO : web interface?
    has_permission_on :threads, :to => :list
    has_permission_on :posts, :to => :read

    # Creation block.  Disable if you want.
    has_permission_on :threads, :to => :create
    # Anonymous may create posts
    has_permission_on :loginposts, :to => :create do
      if_attribute :user => is { nil }
    end
    # May register
    has_permission_on :users, :to => :create
  end

  role :banned do
    # We do not include guest, as a banened user may have even less rights than a guest
    #includes :guest
    has_permission_on :threads, :to => :list

    # PMs are aready tied to the current_user as a sender, so there's no need to check attributes
    has_permission_on :private_messages, :to => :index
    # However, user can't reply to others' messages
    has_permission_on :private_messages, :to => :create do
      if_attribute :viewable_by => contains { user }
    end

    # User may edit his own profile
    has_permission_on :users, :to => :update do
      if_attribute :id => is { user.id }
    end

    # Presentations are aready tied to the current_user as an owner, so there's no need to check attributes
    has_permission_on :presentations, :to => :index
    # However, user can't reply to others' messages
    has_permission_on :presentations, :to => :create do
      if_attribute :user => is { user }
    end
  end

  role :user do
    includes :guest
    includes :banned
    has_permission_on :threads, :to => :create

    # User may edit his own posts
    has_permission_on :posts, :to => :update do
      if_attribute :user => is { user }
    end

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
    has_permission_on :users, :to => :manage
  end
end

privileges do
  # default privilege hierarchies to facilitate RESTful Rails apps
  privilege :manage, :includes => [:create, :read, :update, :delete]
  privilege :read, :includes => [:show]
  privilege :list, :includes => [:read, :index]
  privilege :create, :includes => :new
  privilege :update, :includes => :edit
  privilege :delete, :includes => :destroy
end
