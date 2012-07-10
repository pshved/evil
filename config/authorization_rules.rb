authorization do
  role :guest do
    # Remove :create here if you don't want unregs to create threads
    # TODO : appconfig
    # TODO : web interface?
    has_permission_on :threads, :to => :list
    has_permission_on :posts, :to => :read
    # See the posts feed
    has_permission_on :posts, :to => :latest

    # Creation block.  Disable if you want.
    has_permission_on :threads, :to => :create
    # Anonymous may create posts
    has_permission_on :loginposts, :to => :create do
      if_attribute :user => is { nil }
    end
    # May register
    has_permission_on :users, :to => :create
    # May view other's profiles
    has_permission_on :users, :to => :read
    # Unreg users can create and edit local presentations
    # Technically, nothing prevents them from accessing other unreg users' views, except for the long random cookie key
    has_permission_on :presentations, :to => [:create, :update], :join_by => :and do
      if_attribute :user => is { nil }
      if_attribute :cookie_key => is_not { nil }
      if_attribute :global => is_not { true }
    end
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
    has_permission_on :users, :to => [:update] do
      if_attribute :id => is { user.id }
    end

    # Presentations are aready tied to the current_user as an owner, so there's no need to check attributes
    has_permission_on :presentations, :to => :index
    has_permission_on :presentations, :to => [:create, :update], :join_by => :and do
      if_attribute :user => is { user }
      if_attribute :global => is_not { true }
    end

    # Show/hide posts
    has_permission_on :posts, :to => :toggle_showhide

    # Pazuzus are aready tied to the current_user as an owner, so there's no need to check attributes
    has_permission_on :pazuzus, :to => [:index, :new]
    has_permission_on :pazuzus, :to => [:create, :update, :delete], :join_by => :and do
      if_attribute :user => is { user }
    end

    # Read information about moderation actions
    has_permission_on :moderation_actions, :to => :list

    # Users can see hidden posts if their message count is big enough
    # TODO: when you'll implement this, add a dummy method "exp_requirement" to Posts model, and make it return a const from initializers
    #has_permission_on :posts, :to => :see_deleted do
      #if_attribute :exp_requirement => lte { user.message_count }
    #end
  end

  role :user do
    includes :guest
    includes :banned
    has_permission_on :threads, :to => :create

    # User may edit his own posts
    has_permission_on :posts, :to => :update, :join_by => :and do
      if_attribute :user => is { user }
      if_attribute :created_at => gt { Time.now - 30.minutes }
    end

    # This is a functionality to create posts
    # TODO: add reply_to param checking
    has_permission_on :loginposts, :to => :create do
      if_attribute :user => is { user }
    end
  end

  role :moderator do
    includes :user

    # Moderators can hide posts (hidden posts are visible only to very mature users; unregs and search robots do not see them)
    has_permission_on :posts, :to => :remove
    # Moderators can see hidden posts
    has_permission_on :posts, :to => :see_deleted
  end

  role :admin do
    includes :moderator
    has_permission_on :threads, :to => :manage
    has_permission_on :users, :to => :manage

    # Manage site-wide configuration options
    has_permission_on :admin_configurables, :to => :manage
    has_permission_on :admin_specials, :to => :manage
    has_permission_on :presentations, :to => :edit_default
    has_permission_on :presentations, :to => [:update,:create] do
      if_attribute :global => is { true }
    end

    # Admins can also remove posts permanently
    has_permission_on :posts, :to => [:manage, :remove]
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
