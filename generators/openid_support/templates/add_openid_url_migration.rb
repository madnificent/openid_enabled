class AddOpenidUrlTo<%= class_name %> < ActiveRecord::Migration
  def self.up
    add_column :<%= table_name %>, :openid_url, :string
  end

  def self.down
    remove_column :<%= table_name %>, :openid_url
  end
end
