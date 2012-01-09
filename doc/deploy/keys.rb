
# Create site_key unless exists
unless defined?(REST_AUTH_SITE_KEY)
        # Prompt for site key unless user has supplied it
        begin
                puts "Please, type long sequence of random characters.  It will be used as SITE_KEY: " if STDIN.tty?
                # We'll wrap key into single quotes, so filter them out
                key = STDIN.gets.chomp.gsub(/'/,"")
        end while key.length < 10
        f = File.open("config/initializers/site_keys.rb","w")
        f.puts <<site_key_end
REST_AUTH_SITE_KEY = '#{key}'

REST_AUTH_DIGEST_STRETCHES = 10

site_key_end
        f.close
end

