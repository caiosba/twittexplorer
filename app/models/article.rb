require 'google_drive'

class Article < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Indexing

  ELASTICSEARCH_MAX_RESULTS = 25

  mapping do
    indexes :location,      type: 'geo_point'
    indexes :lang,          type: 'string'
    indexes :content,       type: 'string'
    indexes :uuid,          type: 'string'
    indexes :published_on,  type: 'integer'
    indexes :user,          type: 'string'
    indexes :project,       type: 'string'
    indexes :is_private,    type: 'boolean'
    indexes :is_removed,    type: 'boolean'
    indexes :has_photo,     type: 'boolean'
    indexes :has_instagram, type: 'boolean'
  end

  def as_indexed_json(_options = {})
    as_json(only: %w(content lang uuid published_on user is_private is_removed has_photo has_instagram project))
    .merge(location: {
      lat: lat.to_f,
      lon: lon.to_f
    })
  end

  def self.search(params)
    query = params[:q]
    options = params || {}
  
    # define search definition
    search_definition = {
      query: {
        bool: {
          must: [
            { term: { is_private: ActiveRecord::ConnectionAdapters::Column.value_to_boolean(params[:is_private]) } },
            { term: { is_removed: ActiveRecord::ConnectionAdapters::Column.value_to_boolean(params[:is_removed]) } },
            { term: { has_photo: ActiveRecord::ConnectionAdapters::Column.value_to_boolean(params[:has_photo]) } },
            { term: { has_instagram: ActiveRecord::ConnectionAdapters::Column.value_to_boolean(params[:has_instagram]) } },
            { term: { project: params[:project] } }
          ]
        }
      }
    }
  
    search_definition[:from] = params[:page].to_i * ELASTICSEARCH_MAX_RESULTS
    search_definition[:size] = ELASTICSEARCH_MAX_RESULTS

    # query
    if query.present?
      search_definition[:query][:bool][:must] << {
        multi_match: {
          query: query,
          fields: %w(lang content uuid user),
          operator: 'and'
        }
      }
    end

    # geo spatial
    if options[:lat].present? && options[:lon].present?
      options[:distance] = 100 if options[:distance].blank?

      search_definition[:query][:bool][:must] << {
        filtered: {
          filter: {
            geo_distance: {
              distance: "#{options[:distance]}mi",
              location: {
                lat: options[:lat].to_f,
                lon: options[:lon].to_f
              }
            }
          }
        }
      }
    end

    # time
    if options[:from].present? && options[:to].present?

      search_definition[:query][:bool][:must] << {
        filtered: {
          filter: {
            range: {
              published_on: {
                lte: Time.parse(options[:to]).to_i,
                gte: Time.parse(options[:from]).to_i
              }
            }
          }
        }
      }
    end

    puts search_definition.inspect

    __elasticsearch__.search(search_definition)
  end

  def url
    'https://twitter.com/' + self.user + '/status/' + self.uuid
  end

  def translate
    w = self.get_worksheet
    row = w.num_rows + 1
    w[row, 1] = self.content
    w[row, 2] = self.url
    w.save
  end

  def added_to_spreadsheet?
    w = self.get_worksheet
    for row in 2..w.num_rows
      if w[row, 2] == self.url
        return true
      end
    end
    false
  end

  protected

  def get_worksheet
    session = spreadsheet = nil
    key = CONFIG['google_id']

    begin
      access_token = Rails.cache.fetch('!google_access_token') do
        generate_google_access_token
      end
      session = GoogleDrive.login_with_oauth(access_token)
      spreadsheet = session.spreadsheet_by_key(key)
    rescue Google::APIClient::AuthorizationError
      access_token = generate_google_access_token
      Rails.cache.write('!google_access_token', access_token)
      session = GoogleDrive.login_with_oauth(access_token)
      spreadsheet = session.spreadsheet_by_key(key)
    end

    w = spreadsheet.worksheet_by_title(self.project)
    if w.nil?
      w = spreadsheet.add_worksheet(self.project)
      w.save
      w[1, 1] = 'source_text'
      w[1, 2] = 'link'
      w[1, 3] = 'translation'
      w[1, 4] = 'comment'
      w[1, 5] = 'translator name'
      w[1, 6] = 'translator web site'
      w[1, 7] = 'commenter'
      w[1, 8] = 'commenter web site'
      w.save
    end
    w
  end

  private

  def generate_google_access_token
    require 'google/api_client'
    require 'google/api_client/client_secrets'
    require 'google/api_client/auth/installed_app'
    
    client = Google::APIClient.new(
      :application_name => 'Twittexplorer',
      :application_version => '1.0.0'
    )
    
    key = Google::APIClient::KeyUtils.load_from_pkcs12(CONFIG['google_pkcs12_path'], CONFIG['google_pkcs12_secret'])
    client.authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => ['https://www.googleapis.com/auth/drive', 'https://spreadsheets.google.com/feeds/'],
      :issuer => CONFIG['google_issuer'],
      :signing_key => key)
    client.authorization.fetch_access_token!
    client.authorization.access_token
  end
end
