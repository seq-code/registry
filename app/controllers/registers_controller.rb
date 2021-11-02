class RegistersController < ApplicationController
  before_action(
    :set_register,
    only: %i[show edit update destroy submit return return_commit approve]
  )
  before_action(
    :authenticate_contributor!, only: %i[new create edit update destroy]
  )
  before_action(:authenticate_curator!, only: %i[return return_commit approve])
  before_action(
    :authenticate_can_view!, only: %i[show]
  )
  before_action(
    :authenticate_can_edit!, only: %i[edit update destroy submit]
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
        Register.where(validated: false, submitted: false)
      when :submitted
        authenticate_curator! && return
        Register.where(validated: false, submitted: true)
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
      if @register.can_edit?(current_user) &&
           @register.save &&
           (!@name || @name.update(register: @register))
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
          raise ActiveRecord::Rollback
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
  end

  # POST /registers/r:abcd/return
  def return_commit
    ActiveRecord::Base.transaction do
      par = { status: 5 }
      @register.names.each do |name|
        name.update!(par) unless name.validated?
      end
      @register.update!(submitted: false, notes: params[:register][:notes])
      # TODO
      # Notify submitter
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
      # TODO
      # Notify submitter
    end

    redirect_to @register
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
