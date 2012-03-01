class AddCookieKeyToPresentation < ActiveRecord::Migration
  def change
    add_column :presentations, :cookie_key, :string
  end
end
