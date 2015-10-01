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
    indexes :is_private,    type: 'boolean'
    indexes :is_removed,    type: 'boolean'
    indexes :has_photo,     type: 'boolean'
    indexes :has_instagram, type: 'boolean'
  end

  def as_indexed_json(_options = {})
    as_json(only: %w(content lang uuid published_on user is_private is_removed has_photo has_instagram))
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
            { term: { has_instagram: ActiveRecord::ConnectionAdapters::Column.value_to_boolean(params[:has_instagram]) } }
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
end
