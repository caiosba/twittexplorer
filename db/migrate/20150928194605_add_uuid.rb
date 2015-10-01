class AddUuid < ActiveRecord::Migration
  def change
    add_column :articles, :uuid, :string
  end
end
