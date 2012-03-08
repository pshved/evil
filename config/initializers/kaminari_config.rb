Kaminari.configure do |config|
  # For pagination testing and demo.  Should be less!
  config.default_per_page = 25
  config.window = 2
  # config.outer_window = 0
  config.left = 2
  # config.right = 0
  # config.page_method_name = :page
  # config.param_name = :page
end
