# frozen_string_literal: true

# API v1 controller for names.
# Uses serializers for JSON responses.
module V1
  class NamesController < ApplicationController
    # GET /v1/names
    def index
      @names = Name.all
      render json: @names, each_serializer: NameSerializer, status: :ok
    end

    # GET /v1/names/:id
    def show
      @name = Name.find(params[:id])
      render json: @name, serializer: NameSerializer, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Name not found' }, status: :not_found
    end
  end
end
