class RegistersController < ApplicationController
  before_action(
    :set_register,
    only: %i[
      show table list cite edit update destroy
      submit return return_commit endorse notification notify
      validate publish new_correspondence
      internal_notes nomenclature_review genomics_review
      observe unobserve
    ]
  )
  before_action(:set_name, only: %i[new create])
  before_action(:set_tutorial, only: %i[new create])
  before_action(
    :authenticate_contributor!, only: %i[new create edit update destroy]
  )
  before_action(
    :authenticate_curator!,
    only: %i[
      return return_commit endorse validate
      internal_notes nomenclature_review genomics_review
    ]
  )
  before_action(
    :authenticate_editor!, only: %i[publish]
  )
  before_action(
    :authenticate_can_view!, only: %i[show table list]
  )
  before_action(:ensure_valid!, only: %i[list])
  before_action(
    :authenticate_can_edit!,
    only: %i[edit update destroy submit notification notify new_correspondence]
  )
  before_action(:authenticate_user!, only: %i[observe unobserve])

  # GET /registers or /registers.json
  def index(status = :validated)
    @extra_title = ''
    @crumbs = ['Register Lists']
    @status = params[:status]
    @status ||= status
    @status = @status.to_s
    @registers =
      case @status.to_sym
      when :user
        authenticate_contributor! && return
        if params[:user]
          authenticate_curator! && return
          user = User.find_by(username: params[:user])
          @extra_title = "by #{user.display_name}"
          user.registers
        else
          current_user.registers
        end
      when :observing
        authenticate_curator! && return
        if params[:user]
          authenticate_curator! && return
          user = User.find_by(username: params[:user])
          @extra_title = "by #{user.display_name}"
          user.observing_registers
        else
          current_user.observing_registers
        end
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
    @registers &&=
      @registers.order(updated_at: :desc)
                .paginate(page: params[:page], per_page: 30)
  end

  # GET /registers/r:abcd
  # GET /registers/r:abcd.json
  def show
    @names = @register.names.order(created_at: :desc)
    @names &&= @names.paginate(page: params[:page], per_page: 30)
    @crumbs = [['Register Lists', registers_url], @register.acc_url]
  end

  # GET /registers/new
  def new
    @register = Register.new
    @registers =
      current_user.registers.where(submitted: false, validated: false)
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
    @registers = current_user.registers.where(submitted: false)

    if @register.can_edit?(current_user) && @register.save &&
         (!@name || @name.add_to_register(@register, current_user)) &&
         (!@tutorial || @tutorial.add_to_register(@register, current_user))
      @register.add_observer(current_user)
      flash[:notice] = 'Register was successfully created'
      if @tutorial
        flash[:notice] += '. Remember to submit register list for evaluation'
      end
    else
      flash[:alert] = 'An error occurred while creating the registration list'
    end

    redirect_to @register
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
    change_status(
      :submit, 'Register list successfully submitted for review', current_user
    )
  end

  # GET /registers/r:abcd/return
  def return
    @register.submitted = false
    @register.validated = false
    @register.notified  = false
  end

  # POST /registers/r:abcd/return
  def return_commit
    change_status(
      :return, 'Register list returned to authors',
      current_user, params[:register][:notes]
    )
  end

  # POST /registers/r:abcd/endorse
  def endorse
    change_status(
      :endorse, 'Register list has been endorsed', current_user
    )
  end

  # GET /registers/r:abc/notify
  def notification
    @register.title ||= @register.propose_title
    @publications = @register.proposing_publications
  end

  # POST /registers/r:abc/notify
  def notify
    # Note that +notify+ handles errors differently, and is incompatible with
    # the standard +change_status+ call used in all other status changes
    if @register.notify(current_user, register_notify_params, params[:doi])
      flash[:notice] = 'The list has been successfully submitted for validation'
      redirect_to(@register)
    else
      @register.title = par[:title]
      @register.abstract = par[:abstract]
      flash[:alert] = 'Please review the errors below'
      notification
      render(:notification)
    end
  end

  # POST /registers/r:abc/validate
  def validate
    change_status(
      :validate, 'Successfully validated the register list', current_user
    )
  end

  # POST /registers/r:abc/publish
  def publish
    # TODO See Register::Status#post_validation
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
          header: { html: { template: 'layouts/_pdf_header' } },
          footer: { html: { template: 'layouts/_pdf_footer' } },
          page_size: 'A4'
        )
      end
    end
  end

  # GET /registers/r:abc/cite.xml
  def cite
  end

  # POST /registers/r:abc/new_correspondence
  def new_correspondence
    @register_correspondence = RegisterCorrespondence.new(
      params.require(:register_correspondence).permit(:message, :notify)
    )
    unless @register_correspondence.message.empty?
      @register_correspondence.user = current_user
      @register_correspondence.register = @register
      if @register_correspondence.save
        @register.add_observer(current_user)
        flash[:notice] = 'Correspondence recorded'
      else
        flash[:alert] = 'An unexpected error occurred with the correspondence'
      end
    end
    redirect_to(@register)
  end

  # GET /register/1/observe
  def observe
    @register.add_observer(current_user)
    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_back(fallback_location: @register)
    end
  end

  # GET /register/1/unobserve
  def unobserve
    @register.observers.delete(current_user)
    if params[:from] && RedirectSafely.safe?(params[:from])
      redirect_to(params[:from])
    else
      redirect_back(fallback_location: @register)
    end
  end

  # POST /registers/r:abc/internal_notes
  def internal_notes
    @register.update_column(
      :internal_notes, params[:register][:internal_notes]
    )
    redirect_back(fallback_location: @register)
  end

  # POST /registers/r:abc/nomenclature_review
  def nomenclature_review
    @register.update_column(
      :nomenclature_review, !@register.nomenclature_review
    )
    redirect_back(fallback_location: @register)
  end

  # POST /registers/r:abc/genomics_review
  def genomics_review
    @register.update_column(:genomics_review, !@register.genomics_review)
    redirect_back(fallback_location: @register)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_register
      @register = Register.find_by(accession: params[:accession])
    end

    # Set tutorial if parameter defined
    def set_tutorial
      return if params[:tutorial].blank?
      @tutorial = Tutorial.find(params[:tutorial])
    end

    # Set name if parameter defined
    def set_name
      return if params[:name].blank?
      @name = Name.find(params[:name])
    end

    # Only allow a list of trusted parameters through.
    def register_params
      params
        .require(:register)
        .permit(
          :publication_id, :publication_pdf, :supplementary_pdf, :record_pdf,
          :title, :abstract
        )
    end

    def register_notify_params
      params.require(:register)
            .permit(
              :title, :abstract, :publication_pdf, :supplementary_pdf,
              :submitter_is_author, :authors_approval,
              :submitter_authorship_explanation
            )
    end

    def authenticate_can_view!
      unless @register&.can_view?(current_user)
        flash[:alert] = 'User cannot access register list'
        redirect_to(root_path)
      end
    end

    def authenticate_can_edit!
      unless @register&.can_edit?(current_user)
        flash[:alert] = 'User cannot edit register list'
        redirect_to(root_path)
      end
    end

    def ensure_valid!
      @register&.validated?
    end

    def change_status(fun, success_msg, *extra_opts)
      if @register.send(fun, *extra_opts)
        flash[:notice] = success_msg
      else
        flash[:alert] = @register.status_alert
      end
      redirect_to(@register)
    rescue ActiveRecord::RecordInvalid => inv
      flash['alert'] =
        'An unexpected error occurred while updating the list: ' +
        inv.record.errors.map { |e| "#{e.attribute} #{e.message}" }.to_sentence
      redirect_to(inv.record)
    end
end
