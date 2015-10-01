class AddUser < ActiveRecord::Migration
  def change
    add_column :articles, :user, :string
  end
end
