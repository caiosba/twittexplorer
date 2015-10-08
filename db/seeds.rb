require 'csv'
Article.delete_all
Article.__elasticsearch__.create_index! force: true
i = 0
CSV.foreach(File.join(Rails.root, 'data', 'ooew-28.csv')) do |row|
  i += 1
  Article.create! content: row[20], lang: "lang:#{row[5]}", lat: row[9].gsub(',', '.').to_f, lon: row[10].gsub(',', '.').to_f, uuid: row[0], published_on: Time.parse(row[18]).to_i, user: row[4], is_private: (row[21] == 'Yes'), is_removed: (row[22] == 'Yes'), has_photo: (row[23] == 'Yes'), has_instagram: (row[24] == 'Yes'), project: row[25]
  puts "#{i}) Created"
end
