class JournalsController < ApplicationController
  # GET /journals
  # GET /journals.json
  def index
    @journals = Publication.where.not(journal: ['', nil])
          .select(:journal).reorder(:journal).distinct
          .paginate(page: params[:page], per_page: 100)
    @crumbs = ['Journals']
  end

  # GET /journals/title
  # GET /journals/title.json
  def show
    @journal = params[:journal]
    @publications = Publication.where(journal: @journal)
          .paginate(page: params[:page], per_page: 10)
    @crumbs = [['Journals', journals_path], @journal]
  end
end
