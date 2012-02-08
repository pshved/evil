require 'autoload/utils'

num = (ARGV[0] || 1000).to_i

def random_user
  User.find :first
end

def random_post
  pmi = Posts.maximum('id') or return nil
  thi = Threads.maximum('id')
  while (thr = Threads.order('id ASC').offset(rand(thi)).limit(1)).nil? ;  end
  pl = thr.first.posts.length
  thr.first.posts[rand(pl)]
end

puts random_post.inspect

cr8 = 1

num.times do
  p = Posts.new(:user => random_user, :host => 'localhost')
  title = generate_random_string(20)
  body = ((rand > 0.5) ? 'body' : '')
  p.user = random_user
  p.text_container = TextContainer.make(title,body)
  at = ( (rand < (0.6 / cr8))? nil : random_post)
  puts at.inspect
  so = p.attach_to(at)
  # This sometimes makes the validation fail (why?) but we'll just ignore it for the purpose of testing.
  cr8 += 1 if so.save
end

