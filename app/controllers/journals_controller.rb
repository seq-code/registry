class JournalsController < ApplicationController
  # GET /journals
  # GET /journals.json
  def index
    require 'will_paginate/array'

    @journals = Publication.distinct.pluck(:journal)
          .paginate(page: params[:page], per_page: 100)
    @crumbs = ['Journals']
  end

  # GET /journals/title
  # GET /journals/title.json
  def show
    @journal = ERB::Util.h(params[:journal])
    @publications = Publication.where(journal: @journal)
          .paginate(page: params[:page], per_page: 10)
    @crumbs = [['Journals', journals_path], @journal]
  end
end
