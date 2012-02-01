# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120201175247) do

  create_table "posts", :force => true do |t|
    t.integer  "user_id"
    t.integer  "text_container_id"
    t.string   "host"
    t.string   "unreg_name"
    t.integer  "thread_id"
    t.integer  "parent_id"
    t.string   "subthread_status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "marks"
    t.string   "back"
  end

  add_index "posts", ["back"], :name => "index_posts_on_back"
  add_index "posts", ["parent_id"], :name => "index_posts_on_parent_id"
  add_index "posts", ["text_container_id"], :name => "index_posts_on_text_container_id"
  add_index "posts", ["thread_id"], :name => "index_posts_on_thread_id"
  add_index "posts", ["user_id"], :name => "index_posts_on_user_id"

  create_table "presentations", :force => true do |t|
    t.integer  "threadpage_size"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "presentations", ["user_id"], :name => "index_presentations_on_user_id"

  create_table "private_messages", :force => true do |t|
    t.integer  "sender_user_id"
    t.integer  "recipient_user_id"
    t.integer  "text_container_id"
    t.integer  "reply_to_id"
    t.string   "stamp"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "private_messages", ["recipient_user_id"], :name => "index_private_messages_on_recipient_user_id"
  add_index "private_messages", ["reply_to_id"], :name => "index_private_messages_on_reply_to_id"
  add_index "private_messages", ["sender_user_id"], :name => "index_private_messages_on_sender_user_id"
  add_index "private_messages", ["stamp"], :name => "index_private_messages_on_stamp"
  add_index "private_messages", ["text_container_id"], :name => "index_private_messages_on_text_container_id"

  create_table "roles", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "role_id"
  end

  create_table "text_containers", :force => true do |t|
    t.integer  "current_revision"
    t.integer  "arity",                                       :default => 1
    t.datetime "created_at"
    t.datetime "updated_at"
    t.enum     "filter",           :limit => [:board, :html], :default => :board
  end

  create_table "text_items", :force => true do |t|
    t.integer  "text_container_id"
    t.integer  "revision"
    t.integer  "number"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "text_items", ["text_container_id", "revision", "number"], :name => "k_rev_i_id", :unique => true
  add_index "text_items", ["text_container_id", "revision"], :name => "k_rev_id"
  add_index "text_items", ["text_container_id"], :name => "index_text_items_on_text_container_id"

  create_table "threads", :force => true do |t|
    t.integer  "head_id"
    t.datetime "updated_at"
    t.datetime "created_at"
  end

  add_index "threads", ["head_id"], :name => "index_threads_on_head_id"

  create_table "user_sessions", :force => true do |t|
    t.string   "login"
    t.string   "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "email"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.string   "persistence_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
