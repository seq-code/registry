class ContactsController < ApplicationController
  before_action :authenticate_curator!
  before_action :set_publication
  before_action :set_contact, only: %i[show]

  # GET /publications/1/contacts
  def index
    @contacts =
      @publication.contacts.paginate(page: params[:page], per_page: 30)
  end

  # GET /publications/1/contacts/1
  def show
  end

  # GET /publications/1/contacts/new
  def new
    @contact = Contact.new(
      publication: @publication, user: current_user, cc: current_user.email,
      subject: '[SeqCode Registry] Regarding your recent publication'
    )
    @contact.message = @contact.default_message
  end

  # POST /publications/1/contacts
  def create
    @contact = Contact.new(
      contact_params.merge(user: current_user, publication: @publication)
    )

    if @contact.save
      flash[:notice] = 'Authors have been contacted'
      redirect_to(@publication)
    else
      flash.now[:danger] = 'Authors could not be contacted'
      render :new
    end
  end

  private
    def set_publication
      @publication = Publication.find(params[:publication_id])
      @crumbs = [
        ['Publications', publications_path],
        [@publication.short_citation, @publication],
        'contact'
      ]
    end

    def set_contact
      @contact = Contact.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def contact_params
      params
        .require(:contact)
        .permit(:to, :cc, :subject, :author_id, :message)
    end
end
