class AddColumns < ActiveRecord::Migration
  def change
    add_column :articles, :lat, :float
    add_column :articles, :lon, :float
    add_column :articles, :lang, :string
  end
end
