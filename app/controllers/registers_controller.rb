class RegistersController < ApplicationController
  before_action(
    :set_register,
    only: %i[
      show table list edit update destroy
      submit return return_commit approve notification notify
      validate publish
    ]
  )
  before_action(
    :authenticate_contributor!, only: %i[new create edit update destroy]
  )
  before_action(
    :authenticate_curator!, only: %i[return return_commit approve validate]
  )
  before_action(
    :authenticate_editor!, only: %i[publish]
  )
  before_action(
    :authenticate_can_view!, only: %i[show table list]
  )
  before_action(
    :authenticate_can_edit!,
    only: %i[edit update destroy submit notification notify]
  )

  # GET /registers or /registers.json
  def index(status = :validated)
    @crumbs = ['Register Lists']
    @status = params[:status]
    @status ||= status
    @status = @status.to_s
    @registers =
      case @status.to_sym
      when :user
        authenticate_contributor! && return
        current_user.registers
      when :draft
        authenticate_curator! && return
        Register.where(validated: false, notified: false, submitted: false)
      when :submitted
        authenticate_curator! && return
        Register.where(validated: false, notified: false, submitted: true)
      when :notified
        authenticate_curator! && return
        Register.where(validated: false, notified: true)
      else # :validated
        Register.where(validated: true)
      end
    @registers = @registers&.paginate(page: params[:page], per_page: 30)
  end

  # GET /registers/r:abcd or /registers/r:abcd.json
  def show
    @names = @register.names.paginate(page: params[:page], per_page: 30)
    @crumbs = [['Register Lists', registers_url], @register.acc_url]
  end

  # GET /registers/new
  def new
    @register = Register.new
    @name = Name.where(id: params[:name]).first
    @registers = current_user.registers.where(submitted: false)
    @crumbs = ['Register Lists']
  end

  # GET /registers/r:abcd/edit
  def edit
  end

  # POST /registers
  def create
    @register = nil
    if params[:existing_register] && !params[:existing_register].empty?
      @register = Register.where(accession: params[:existing_register]).first
    end
    @register ||= Register.new(user: current_user)
    @name = Name.where(id: params[:name]).first
    @registers = current_user.registers.where(submitted: false)

    respond_to do |format|
      if @register.can_edit?(current_user) && @register.save &&
           (!@name || @name.add_to_register(@register, current_user))
        format.html { redirect_to @register, notice: "Register was successfully created." }
        format.json { render :show, status: :created, location: @register }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @register.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /registers/r:abcd or /registers/r:abcd.json
  def update
    respond_to do |format|
      if @register.update(register_params)
        format.html { redirect_to @register, notice: "Register was successfully updated." }
        format.json { render :show, status: :ok, location: @register }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @register.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /registers/r:abcd or /registers/r:abcd.json
  def destroy
    ActiveRecord::Base.transaction do
      @register.names.each { |i| i.update!(register: nil) }
      @register.destroy!
    end
    respond_to do |format|
      format.html { redirect_to registers_url, notice: "Register was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # POST /registers/r:abcd/submit
  def submit
    ActiveRecord::Base.transaction do
      par = { status: 10, submitted_at: Time.now, submitted_by: current_user }
      @register.names.each do |name|
        if name.after_submission?
          flash[:alert] = 'Some names in the list have already been submitted'
        end
        name.update!(par)
      end
      @register.update!(submitted: true)
      flash[:notice] = 'Register list successfully submitted for review'
    end

    redirect_to @register
  end

  # GET /registers/r:abcd/return
  def return
    @register.submitted = false
    @register.validated = false
    @register.notified  = false
  end

  # POST /registers/r:abcd/return
  def return_commit
    ActiveRecord::Base.transaction do
      par = { status: 5 }
      @register.names.each { |name| name.update!(par) unless name.validated? }
      @register.update!(
        submitted: false, notified: false, notes: params[:register][:notes]
      )
      # TODO Notify submitter
    end

    redirect_to @register
  end

  # POST /registers/r:abcd/approve
  def approve
    ActiveRecord::Base.transaction do
      par = { status: 12, approved_by: current_user, approved_at: Time.now }
      @register.names.each do |name|
        name.update!(par) unless name.after_approval?
      end
      # TODO Notify submitter
    end

    redirect_to(@register)
  end

  # GET /registers/r:abc/notify
  def notification
    @register.title ||= @register.propose_title
    @publications = @register.proposing_publications
  end

  # POST /registers/r:abc/notify
  def notify
    par = params.require(:register).permit(
      :title, :abstract, :publication_pdf, :supplementary_pdf
    ).merge(notified: true, notified_at: Time.now)
    @register.title = par[:title]
    @register.abstract = par[:abstract]

    all_ok = false
    publication = Publication.by_doi(params[:doi])
    par[:publication] = publication
    if publication.new_record?
      @register.errors.add(:doi, publication.errors[:doi].join('; '))
    elsif !par[:publication_pdf] && !@register.publication_pdf.attached?
      @register.errors.add(:publication_pdf, 'cannot be empty')
    else
      par[:publication] = publication
      ActiveRecord::Base.transaction do
        @register.names.each do |name|
          unless name.after_approval?
            flash[:warning] = 'Some names in the list have not been approved ' +
              'yet and will require expert review, which could delay validation'
            name.status = 10
            name.submitted_at = Time.now
            name.submitted_by = current_user
          end

          unless name.publications.include? publication
            name.publications << publication
          end
          name.proposed_by ||= publication
          name.save!
        end
        @register.update!(par)
        all_ok = true
      end
    end

    if all_ok
      HeavyMethodJob.perform_later(:automated_validation, @register)
      flash[:notice] = 'The list has been successfully submitted for validation'
      redirect_to(@register)
    else
      flash[:alert] = 'Please review the errors below'
      notification
      render(:notification)
    end
  end

  # POST /registers/r:abc/validate
  def validate
    success = true

    if @register.validate!(current_user)
      flash['notice'] = 'Successfully validated the register list'
    else
      flash['alert'] = 'An unexpected error occurred while validating the list'
    end
    redirect_to(@register)
  end

  # POST /registers/r:abc/publish
  def publish
    # TODO See Register#post_validation
  end

  # GET /registers/r:abc/table
  # GET /registers/r:abc/table.pdf
  def table
    respond_to do |format|
      format.html
      format.pdf do
        render(
          template: 'registers/table.html.erb',
          pdf: "Register List #{@register.acc_url}",
          orientation: 'Landscape',
          page_size: 'A4'
        )
      end
    end
  end

  # GET /registers/r:abc/list
  # GET /registers/r:abc/list.pdf
  def list
    respond_to do |format|
      format.html
      format.pdf do
        render(
          template: 'registers/list.html.erb',
          pdf: "Register List #{@register.acc_url}",
          page_size: 'A4'
        )
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_register
      @register = Register.find_by(accession: params[:accession])
    end

    # Only allow a list of trusted parameters through.
    def register_params
      params.require(:register)
            .permit(
              :publication_id, :publication_pdf, :supplementary_pdf, :record_pdf
            )
    end

    def authenticate_can_view!
      unless @register.can_view?(current_user)
        flash[:alert] = 'User cannot access register list'
        redirect_to(root_path)
      end
    end

    def authenticate_can_edit!
      unless @register.can_edit?(current_user)
        flash[:alert] = 'User cannot edit register list'
        redirect_to(root_path)
      end
    end
end
