class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  @@search_obj = {
    publications: [Publication, %w[title doi journal abstract]],
    authors: [Author, %w[given family]],
    names: [Name, %w[name]],
    subjects: [Subject, %w[name]]
  }

  def main
    @publications = Publication.all.order(journal_date: :desc)
    @authors = Author.all.order(created_at: :desc)
    @names = Name.all.order(created_at: :desc)
  end

  def search
    if [:what, :q].any? { |i| params[i].nil? }
      render :search_query
    else
      @what = params[:what].to_sym
      if @@search_obj[@what]
        @q = params[:q]
        @results = search_by(@what).paginate(page: params[:page],
            per_page: @what == :authors ? 100 : @what == :publications ? 10 : 30)
        redirect_to @results.first if @results.count == 1
      else
        flash[:danger] = 'Unsupported object.'
        redirect_to root_url
      end
    end
  end

  def search_query
  end

  private
    
    def search_by(k)
      obj = @@search_obj[k]
      o = obj[0].none
      obj[1].each do |i|
        o = o.or(obj[0].where("LOWER(#{i}) LIKE ?", "%#{@q.downcase}%"))
      end
      o
    end
end
