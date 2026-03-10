# typed: false

class TmdbController < ApplicationController
  before_action :set_service

  def trending
    page = params.fetch(:page, 1)
    render json: @tmdb.trending_movies(page: page)
  end

  def search
    query = params.require(:query)
    page = params.fetch(:page, 1)
    type = params.fetch(:type, "movie")

    result = if type == "tv"
      @tmdb.search_tv(query: query, page: page)
    else
      @tmdb.search_movies(query: query, page: page)
    end

    render json: result
  end

  def movie
    render json: @tmdb.movie_details(id: params[:id])
  end

  def tv
    render json: @tmdb.tv_details(id: params[:id])
  end

  def season
    render json: @tmdb.season_details(tv_id: params[:id], season: params[:season])
  end

  private

  def set_service
    @tmdb = TmdbService.new
  end
end
