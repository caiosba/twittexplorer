class AddProject < ActiveRecord::Migration
  def change
    add_column :articles, :project, :string
    Article.update_all("project = 'refugees'")
  end
end
