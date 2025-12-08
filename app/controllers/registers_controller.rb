class RegistersController < ApplicationController
  before_action(
    :set_register,
    only: %i[
      show table list certificate_image cite edit update destroy tree
      submit return return_commit endorse prenotify prenotify_commit
      notify notify_commit validate coauthors coauthors_commit
      editorial_checks publish publish_commit new_correspondence
      internal_notes nomenclature_review genomics_review snooze_curation
      recheck_pdf_files curation_genomics transfer_user transfer_user_commit
      observe unobserve merge merge_commit sample_map
      reviewer_token reviewer_token_create reviewer_token_delete
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
      internal_notes nomenclature_review genomics_review snooze_curation
      recheck_pdf_files curation_genomics transfer_user transfer_user_commit
    ]
  )
  before_action(
    :authenticate_editor!, only: %i[editorial_checks publish publish_commit]
  )
  before_action(
    :authenticate_can_view!,
    only: %i[
      show table list certificate_image new_correspondence sample_map tree
      reviewer_token
    ]
  )
  before_action(:ensure_valid!, only: %i[list certificate_image])
  before_action(
    :authenticate_can_edit!,
    only: %i[
      edit update destroy submit prenotify prenotify_commit notify notify_commit
      merge merge_commit reviewer_token_create reviewer_token_delete
      coauthors coauthors_commit
    ]
  )
  before_action(:authenticate_user!, only: %i[observe unobserve])
  before_action(:check_pending_genomes!, only: %i[notify notify_commit])

  # GET /registers or /registers.json
  def index(status = :validated)
    @extra_title = ''
    @crumbs = ['Lists']
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

  # GET /registers/map
  def map
    @crumbs     = [['Lists', registers_url], 'Map']
    @registers  = Register.where(validated: true)
    @sample_set = CollectionSampleSet.new(@registers)
    render(
      'genomes/sample_map',
      layout: !params[:content].present?,
      cached: [params[:content], params[:label]]
    )
  end

  # GET /registers/r:abcd
  # GET /registers/r:abcd.json
  def show
    if @register.names.any? { |n| n.name_order.nil? }
      @register.update_name_order
    end
    @names = @register.names.order(:name_order, created_at: :desc)
    @count = @names.count
    @names &&= @names.where(rank: params[:rank]) if params[:rank].present?
    @names &&= @names.paginate(page: params[:page], per_page: 30)
    @crumbs = [['Lists', registers_url], @register.acc_url]
  end

  # GET /registers/r:abcd/tree
  def tree
    @crumbs = [
      ['Lists', registers_url], [@register.acc_url, @register], 'Tree view'
    ]
    @register.update_name_order
  end

  # GET /registers/new
  def new
    @register = Register.new
    @registers =
      current_user.registers.where(submitted: false, validated: false)
    @crumbs = ['Lists']
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
        format.html { redirect_to @register, notice: 'Register was successfully updated.' }
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
      format.html { redirect_to registers_url, notice: 'Register was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # POST /registers/r:abcd/submit
  def submit
    change_status(
      :submit, 'Register list successfully submitted for review', current_user
    )
    add_automatic_correspondence('Register list submitted')
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

  # GET /registers/r:abc/prenotify
  def prenotify
    @errored ||= {}
    @genomes = @register.names.map(&:type_genome).compact.select(&:pending?)
    redirect_to(notify_register_path(@register)) if @genomes.empty?
  end

  # POST /registers/r:abc/prenotify
  def prenotify_commit
    @errored = {}
    params.require(:genome).each do |k, v|
      genome = Genome.find(k.to_i)
      unless genome&.update_accession(v['accession'], v['database'])
        @errored[k.to_i] = 'Cannot update accession'
      end
    end

    prenotify
    render(:prenotify) unless @genomes.empty?
  end

  # GET /registers/r:abc/notify
  def notify
    @register.title ||= @register.propose_title
    @publications = @register.proposing_publications
    @crumbs = [
      ['Lists', registers_url],
      [@register.acc_url, @register],
      'Notification'
    ]
  end

  # POST /registers/r:abc/notify
  def notify_commit
    # Note that +notify+ handles errors differently, and is incompatible with
    # the standard +change_status+ call used in all other status changes
    par = register_notify_params
    if @register.notify(current_user, par, params[:doi])
      flash[:notice] = 'The list has been successfully submitted for validation'
      add_automatic_correspondence('SeqCode Register notified')
      redirect_to(@register)
    else
      @register.title = par[:title]
      @register.abstract = par[:abstract]
      flash[:alert] = 'Please review the errors below'
      notify
      render(:notify)
    end
  end

  # POST /registers/r:abc/validate
  def validate
    change_status(
      :validate, 'Successfully validated the register list', current_user
    )
  end

  # GET /registers/r:abc/coauthors
  def coauthors
    @crumbs = [
      ['Lists', registers_url], [@register.acc_url, @register], 'Coauthors'
    ]
  end

  # POST /registers/r:abc/coauthors
  def coauthors_commit
    @register.coauthor = params.require('register').require('coauthor')
    @coauthor = User.find_by_email_or_username(@register.coauthor)
    if @coauthor.present?
      rc_par = { register: @register, user: @coauthor }
      notify = true
      rc =
        case params['register']['action']
        when 'unlink'
          RegisterCoauthor.find_by(rc_par).destroy
        when 'up'
          notify = false
          RegisterCoauthor.find_by(rc_par).tap(&:move_up)
        else
          rc_par.merge!(order: @register.register_coauthors.size + 1)
          RegisterCoauthor.new(rc_par).tap(&:save)
        end

      if rc && !rc.errors.present?
        Notification.create(
          user: @coauthor, notifiable: @register,
          action: :coauthor_register, title: 'Authorship status changed'
        ) if notify
        flash[:notice] = 'Successfully updated coauthors'
        redirect_back(fallback_location: @register)
      else
        flash.now[:alert] = 'Error updating coauthors'
        rc.errors.each do |field, err|
          @register.errors.add(:coauthor, err)
        end
        coauthors
        render :coauthors
      end
    else
      @register.errors.add(:coauthor, 'does not exist in the system')
      coauthors
      render :coauthors
    end
  end

  # GET /registers/r:abc/editorial_checks
  def editorial_checks
    @crumbs = [
      ['Lists', registers_url],
      [@register.acc_url, @register],
      'Editorial checks'
    ]
  end

  # GET /registers/r:abc/publish
  def publish
    @crumbs = [
      ['Lists', registers_url],
      [@register.acc_url, @register],
      'Publish'
    ]
  end

  # POST /registers/r:abc/publish
  def publish_commit
    change_status(
      :publish, 'Successfully published the register list', current_user,
      params[:datacite_action]
    )
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

  # GET /registers/r:abc/certificate_image.pdf
  def certificate_image
    respond_to do |format|
      format.pdf do
        send_data(
          @register.certificate_image,
          disposition: 'inline',
          filename: 'seqcode-%s.pdf' % @register.accession.gsub(':', '-'),
          type: 'application/pdf'
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
        @register.unsnooze_curation!
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
    if @register.nomenclature_review
      @register.names.each do |name|
        name.update_column(:nomenclature_review_by_id, current_user.id)
      end
      add_automatic_correspondence('Nomenclature review complete')
    end
    redirect_back(fallback_location: @register)
  end

  # POST /registers/r:abc/genomics_review
  def genomics_review
    @register.update_column(
      :genomics_review, !@register.genomics_review
    )
    if @register.genomics_review
      @register.names.each do |name|
        name.update_column(:genomics_review_by_id, current_user.id)
      end
      add_automatic_correspondence('Genomics review complete')
    end
    redirect_back(fallback_location: @register)
  end

  # POST /registers/r:abc/snooze_curation?time=10
  def snooze_curation
    @register.snooze_curation!(Time.now + params[:time].to_i.days)
    redirect_back(fallback_location: @register)
  end

  # POST /registers/r:abc/recheck_pdf_files
  def recheck_pdf_files
    if @register.notified?
      begin
        @register.check_pdf_files
        flash[:notice] = 'Attached files successfully evaluated'
      rescue => e
        flash[:alert] = e.to_s
      end
    else
      flash[:alert] = 'The list has not been notified'
    end
    redirect_back(fallback_location: @register)
  end

  # GET /register/r:abc/transfer_user
  def transfer_user
  end

  # POST /register/r:abc/transfer_user
  def transfer_user_commit
    old_user = @register.user
    username = params.require(:register)[:user]
    user = User.find_by_email_or_username(username)

    if !user.present?
      flash[:alert] = 'The user could not be found'
      render :transfer_user
    elsif @register.transfer(current_user, user)
      add_automatic_correspondence(
        'SeqCode Register transferred from %s to %s' % [
          old_user&.username, user&.username
        ]
      )
      flash[:notice] =
        'List and name(s) successfully transferred to the new user'
      redirect_to(@register)
    else
      flash[:alert] =
        'The list has not been transferred due to a failed check: ' +
        @register.status_alert
      render :transfer_user
    end
  end

  # GET /registers/r:abc/merge
  def merge
    @crumbs = [
      ['Lists', registers_url],
      [@register.acc_url, @register],
      'Merge'
    ]
    @target_registers =
      @register.user.registers.where(validated: false) - [@register]
  end

  # POST /registers/r:abc/merge
  def merge_commit
    @target_register = Register.find_by(accession: params[:target])
    if @register.merge_into(@target_register, current_user)
      flash[:notice] = 'Register list successfully transferred'
      redirect_to(@register)
    else
      merge
      render(:merge)
    end
  end

  # GET /registers/r:abc/sample_map
  def sample_map
    @crumbs = [['Lists', registers_url], [@register.acc_url, @register], 'Map']
    @sample_set = @register.sample_set
    render('genomes/sample_map', layout: !params[:content].present?)
  end

  # GET /registers/r:abc/reviewer_token
  def reviewer_token
    @crumbs = [
      ['Lists', registers_url],
      [@register.acc_url, @register],
      'Reviewer access'
    ]
  end

  # POST /registers/r:abc/reviewer_token
  def reviewer_token_create
    require 'securerandom'
    require 'digest'

    token = SecureRandom.urlsafe_base64(25).downcase
    if @register.update_column(:reviewer_token, token)
      flash[:notice] = 'Reviewer link successfully created'
    else
      flash[:alert] = 'An unexpected error occurred, please report it'
    end
    redirect_to(@register)
  end

  # DELETE /registers/r:abc/reviewer_token
  def reviewer_token_delete
    if @register.update_column(:reviewer_token, nil)
      flash[:notice] = 'Reviewer link permanently deactivated'
    else
      flash[:alert] = 'An unexpected error occurred, please report it'
    end
    redirect_to(@register)
  end

  # GET /registers/r:abcd/curation_genomics
  def curation_genomics
    @names =
      @register.names
        .order(:name_order, created_at: :desc)
        .where(rank: %w[species subspecies])
        .paginate(page: params[:page], per_page: 30)
    @checks = {
      ambiguous_type_genome: [:ambiguous_type_genome],
      inconsistent_16s_assignment: [:inconsistent_16s_assignment],
      missing_metadata_in_databases: [:missing_metadata_in_databases],
      all_genomics: []
    }
    @check = (params[:check] || @checks.keys.first).to_sym
    @check_k = @checks.keys.index(@check)
    @crumbs = [
      ['Lists', registers_url],
      [@register.acc_url, @register],
      'genomics'
    ]
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_register
      @no_register_sentinel = true
      @register = Register.find_by(accession: params[:accession])

      if params[:token]
        if params[:token] == 'no'
          cookies[:reviewer_token] = nil
        elsif @register.reviewer_token == params[:token]
          cookies[:reviewer_token] = params[:token]
        end
      end

      current_user
        &.unseen_notifications
        &.where(notifiable: @register)
        &.update(seen: true)
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
      unless @register&.can_view?(current_user, cookies[:reviewer_token])
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

    def check_pending_genomes!
      if @register.pending_genomes?
        redirect_to(prenotify_register_path(@register))
      end
    end

    def add_automatic_correspondence(message)
      RegisterCorrespondence.new(
        message: message, notify: '0', automatic: true,
        user: current_user, register: @register
      ).save
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
