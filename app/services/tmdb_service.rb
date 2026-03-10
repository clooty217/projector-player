# typed: false

require "net/http"
require "json"

class TmdbService
  BASE_URL = "https://api.themoviedb.org/3"

  def initialize
    @api_key = ENV.fetch("TMDB_API_KEY")
  end

  def trending_movies(page: 1)
    get("/trending/movie/week", page: page)
  end

  def search_movies(query:, page: 1)
    get("/search/movie", query: query, page: page)
  end

  def search_tv(query:, page: 1)
    get("/search/tv", query: query, page: page)
  end

  def movie_details(id:)
    get("/movie/#{id}")
  end

  def tv_details(id:)
    get("/tv/#{id}")
  end

  def season_details(tv_id:, season:)
    get("/tv/#{tv_id}/season/#{season}")
  end

  private

  def get(path, **params)
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params.compact)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Accept"] = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end
