#!/usr/bin/env ruby
# Initializer script that creates basic users for the application to perform
usage=<<usage
	rails runner doc/deploy/users.rb admin@email.com admin_password
usage

# Parse options
admin_mail, admin_password = ARGV

if admin_password.nil?
        puts usage
        exit 1
end

# Create ADMIN user and set up properties
admin_user = User.find_or_create_by_login('admin')
admin_user.email = admin_mail
admin_user.password = admin_user.password_confirmation = admin_password
# Set admin role
admin_user.roles += [Role.find_or_create_by_name('admin')]

# Save and activate user
#admin_user.register or throw "can't register admin"
#admin_user.activate or throw "can't activate admin"
admin_user.save

# Create roles
%w(guest user moderator admin banned).each do |role_name|
	Role.find_or_create_by_name(role_name)
end


