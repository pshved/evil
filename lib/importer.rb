# coding: utf-8
require 'autoload/utils'
require 'xml'
class Importer
  def self.mkuser(scope,nick)
    name = "#{scope}:#{nick}"
    u = User.find_by_login(name)
    unless u
      pwd = generate_random_string(13)
      u = User.create({:login => name, :password => pwd, :password_confirmation => pwd, :email => "mail_#{generate_random_string(22)}@example.com"}, :without_protection => true)
    end
    u
  end

  def self.msg_node(doc,id)
    doc.find(%Q(/descendant-or-self::message[@id="#{id.to_i}"])).first
  end

  def self.mk_user_or_unreg(name,id,doc)
    author_node = msg_node(doc,id).find(%Q(author)).first
    registered = author_node.find(%Q(registered)).first.content
    username = author_node.find(%Q(name)).first.content
    host = author_node.find(%Q(host)).first.content
    common = {:host => host}
    unless registered == 'true'
      common.merge :unreg_name => username
    else
      common.merge :user => mkuser(name,username)
    end
  end

  def self.post(source,id,fmt,page,enc = 'UTF-8')
    case fmt
    when 'xmlfp'
      puts [source,id,fmt].inspect
      # Parse the incoming page
      doc = XML::Parser.string(page, :options => XML::Parser::Options::RECOVER).parse
      # When importing multiple posts, we may, in fact, encounter a situation when not every message ID we requested is in the output.  To fix this, we check if there is a proper message node in the input.
      mn = msg_node(doc,id)
      if mn.nil? || (mn.find(%Q(status)).first && mn.find(%Q(status)).first.content == 'not_exists')
        puts "No node with id=#{id} found!  Not importing."
        return nil
      end
      # mp will be the hash that contains the new post's parameters
      mp = {}
      # Get user
      mp = mp.merge(mk_user_or_unreg(source.name,id,doc))
      # Get post contents and timestamp
      mp[:body] = (body = mn.find(%Q(content/body)).first) ? body.content : ''
      mp[:title] = mn.find(%Q(content/title)).first.content
      mp[:created_at] = Time.parse(mn.find(%Q(info/date)).first.content)
      # Find the post this one replies to, and attach this post to it
      parent_back_id = nil
      parent_post = if pp_node = mn.find(%Q(info/parentId)).first
                      parent_back_id = pp_node.content
                      pp_import = source.imports.where(:back => parent_back_id).first
                      pp_import && pp_import.post
                    else
                      nil
                    end
      # Create an import signature for this post as well
      new_import = Import.where(:source_id => source.id, :back => id, :reply_to => parent_back_id).first || Import.new(:source_id => source.id, :back => id, :reply_to => parent_back_id)
      # Create/update the post itself
      new_post = new_import.post || Posts.new
      new_post.assign_attributes(mp, :without_protection => true)

      # Set up HTML (raw) filter, so that boardtags are not applied
      new_post.text_container.filter = :html

      # Attach the post to its imported parent or to a new thread
      to_save = new_post.thread ? new_post : new_post.attach_to(parent_post)
      new_import.post = new_post
      Import.transaction do
        # A post with a thread doesn't need to be attached
        to_save.save!
        new_import.save!
      end

      # Merge threads of children of this post

      # If the post has successfully been saved, we merge all replies to it into its thread.
      this_thread = (to_save.is_a? Threads) ? to_save : to_save.thread
      threads_to_rm = {}
      source.imports.where(:reply_to => id).each do |import|
        threads_to_rm[import.post.thread.id] = true
        import.post.parent = new_post
        import.post.save!
      end
      # Update thread id-s in the posts being merged, and remove the threads
      threads_to_rm.keys.each do |thr_id|
        next if thr_id == this_thread.id
        thr = Threads.find thr_id
        thr.posts.update_all :thread_id => this_thread.id
        thr.delete
      end

      # Fix thread update time
      created_at = new_post.thread.head.created_at
      updated_at = new_post.thread.posts.maximum('created_at')
      # Can't just save, since it will not allow us to set updated_at
      Threads.where(:id => this_thread.id).update_all :created_at => created_at
      Threads.where(:id => this_thread.id).update_all :updated_at => updated_at
      # Unset the updated_at time of this post
      Posts.where(:id => new_post.id).update_all :updated_at => new_post.created_at

      # Return the new post
      new_post
    else
      raise "Unknown format: #{fmt}"
    end
  end

  def self.conv(str,from = 'UTF-8')
    return str if from.upcase == 'UTF-8'
    Encoding::Converter.new(from,'UTF-8').convert str
  end
end
