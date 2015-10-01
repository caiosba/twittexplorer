class AddBoolFields < ActiveRecord::Migration
  def change
    add_column :articles, :is_private, :boolean
    add_column :articles, :is_removed, :boolean
    add_column :articles, :has_photo, :boolean
    add_column :articles, :has_instagram, :boolean
  end
end
