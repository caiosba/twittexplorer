class ChangeTime < ActiveRecord::Migration
  def change
    remove_column :articles, :published_on
    add_column :articles, :published_on, :integer
  end
end
