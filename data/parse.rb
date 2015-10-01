require 'csv'
require 'twitter'

LIMIT = 900 # How many requests until wait (180 per key each 15 minutes)
WINDOW = 900 # How much time to wait after limit is reached (900 seconds = 15 minutes)

# Check if input file is provided

if ARGV.length == 0
  puts 'Please provide the input CSV file as an argument'
  exit
end

# Open input and output files

infile = ARGV.first
outfile = infile.gsub(/\.csv$/, '-parsed.csv')
output = File.open(outfile, 'a+')

twitter1 = Twitter::REST::Client.new do |config|
  config.consumer_key        = 'M5c3Frb9yS29UFww3jsH7g4aw'
  config.consumer_secret     = 's46hFR5bmkr0uJUI44uv2LdkMO8fhj6H7G5LkPf4aMS22o8roa'
  config.access_token        = '21530857-xpY0h10pGvfxQ9HRoQxCBWMAdoIg94pGBIdbpgi2M'
  config.access_token_secret = 'nE1cfivnXm4Y3j9PlSRrTXwN98C6dhqGUgKK5kKluO9w0'
end

twitter2 = Twitter::REST::Client.new do |config|
  config.consumer_key        = 'H1ftBT43SqVDXa77FE92d0HzB'
  config.consumer_secret     = 'AHRtuzr5BwKkI4v27obf0XwsYYFZjoiGpAximdkon3wNnBS5HW'
  config.access_token        = '21530857-gaxgVDLRWFSkT0Ee7SDeGTvG4W3tAfKSLEu3zuaXl'
  config.access_token_secret = 'uO4cPfE0UIz1ezXGTeQhj7o3CbjXQdZ38j6XaKFmz7uXA'
end

twitter3 = Twitter::REST::Client.new do |config|
  config.consumer_key        = 'P1arvv5SCyHDjKlb5WNTv1HXT'
  config.consumer_secret     = 'vszCuLSD2bHywHElcTkfJ7FugWCfSxEQCODbCz8FAxzlY7W8Tw'
  config.access_token        = '21530857-nTmQpC6bEXl7tOA8nbuwNUB1thEcqrzkAsH6hMHGd'
  config.access_token_secret = 'ztZz0T6l7QKNNkUan2gSasV1svCVnvBwrZWwhjYivaXJc'
end

twitter4 = Twitter::REST::Client.new do |config|
  config.consumer_key        = 'PMFTyDOGVEb6mNwOEs8dWnR4g'
  config.consumer_secret     = 'sIdHSNc5PazklVELjBkuyVTQLzLFI4xwf7d84x5vrxjyelwCuZ'
  config.access_token        = '21530857-rzeSRFUYmXlPg3qDWe14tEorrGOrekPxCcwRouK3U'
  config.access_token_secret = '1jbjiXuJvyoafm0qTvZJD60emrJVHzm2d5wpldiZqvbgZ'
end

twitter5 = Twitter::REST::Client.new do |config|
  config.consumer_key        = 'u6Q4EU18yzStFVJJti2SDQ'
  config.consumer_secret     = '2H8g0HfZBjclYUX0wDRj8u5eXCGDw9IIjwCKkJH63FY'
  config.access_token        = '21530857-6WR9MiQMrVr4zB4NtN4gEwEingAmmp58Yg2FkiJMd'
  config.access_token_secret = 'vAnkm8kLr6RQyFnhuF2hj7UBaKS04CFP3c2NvCNgyg'
end

twitter = [twitter1, twitter2, twitter3, twitter4, twitter5]

# Iterate through each line

input = File.read(infile)
csv = CSV.parse(input, headers: true)
i = 0
csv.each do |row|
  tweet = nil
  data = row.to_hash
  id = data['id']

  # Write the header
  
  output.puts((data.keys + ['Private?', 'Removed?', 'Photo?', 'Instagram?']).join(',')) if i == 0

  # Initialize variables

  priv = removed = photo = instagram = 'No'

  # Get the tweet from Twitter

  begin
    tweet = twitter[i % 5].status(id)

  # Tweet removed

  rescue Twitter::Error::NotFound
    removed = 'Yes'

  # Private tweet

  rescue Twitter::Error::Forbidden
    priv = 'Yes'

  # Publicly available tweet

  else

    # Has photo

    tweet.media.each { |media| photo = 'Yes' if media.is_a?(Twitter::Media::Photo) } unless tweet.media.empty?

    # Has Instagram

    instagram = 'Yes' unless tweet.urls.map(&:expanded_url).map(&:host).select{ |url| url == 'instagram.com' }.empty?
  end

  # Write to output file

  values = data.values + [priv, removed, photo, instagram]
  values = values.collect{ |v| '"' + v.to_s + '"' }
  output.puts values.join(',')
  
  puts "#{i}. Parsing tweet #{id} (#{values})"

  i += 1

  # If we reached the limit, wait until making more requests to Twitter

  if i % LIMIT == 0
    puts "Limit reached, let's wait for 15 minutes..."
    sleep WINDOW
  end
end

output.close
