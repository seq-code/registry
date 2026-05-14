# frozen_string_literal: true

# Base controller for Names-related controllers.
# Contains shared logic, before_actions, and private methods.
class Names::BaseController < ApplicationController
  before_action :set_tutorial

  # Authentication and authorization methods
  before_action :authenticate_user!, only: %i[observe unobserve observing]
  before_action :authenticate_contributor!, only: %i[new create claim]
  before_action :authenticate_admin!, only: %i[demote temporary_editable]
  before_action :authenticate_curator!, only: %i[unranked unknown_proposal submitted endorsed draft return validate endorse edit_redirect]
  before_action :authenticate_owner_or_curator!, only: %i[unclaim new_correspondence transfer_user transfer_user_commit]
  before_action :authenticate_can_edit!, only: %i[edit destroy proposed_in not_validly_proposed_in emended_in assigned_in corrigendum_in corrigendum_orphan corrigendum edit_description edit_rank edit_notes edit_etymology autofill_etymology edit_parent]
  before_action :authenticate_can_edit_type!, only: %i[edit_type]
  before_action :authenticate_can_edit_validated!, only: %i[update edit_links]

  # Setup methods
  before_action :set_name_and_notifications, only: %i[show]
  before_action :set_name, only: %i[edit update destroy network wiki proposed_in not_validly_proposed_in emended_in assigned_in corrigendum_in corrigendum_orphan corrigendum edit_description edit_rank edit_notes edit_etymology edit_links edit_type edit_redirect autofill_etymology edit_parent return validate endorse claim unclaim demote temporary_editable transfer_user transfer_user_commit new_correspondence observe unobserve quality_checks]

  private

  # Use callbacks to share common setup or constraints between actions
  def set_name_and_notifications
    if set_name
      current_user
        &.unseen_notifications
        &.where(notifiable: @name)
        &.update(seen: true)
    end
  end

  def set_name
    @name = Name.find(params[:id])

    if @name&.can_view?(current_user, cookies[:reviewer_token])
      @register = @name.try(:register)
      true
    else
      render 'hidden'
      false
    end
  end

  def set_tutorial
    return if params[:tutorial].blank?
    @tutorial = Tutorial.find(params[:tutorial])
  end

  def authenticate_owner_or_curator!
    unless current_user.try(:curator?) || @name.user?(current_user)
      flash[:alert] = 'User is not the owner of the name'
      redirect_to(@name)
    end
  end

  def authenticate_can_edit_validated!
    unless @name.can_edit_validated?(current_user)
      flash[:alert] = 'User cannot edit this aspect of the name'
      redirect_to(@name)
    end
  end

  def authenticate_can_edit_type!
    unless @name.can_edit_type?(current_user)
      flash[:alert] = 'User cannot edit the nomenclatural type'
      redirect_to(@name)
    end
  end

  def authenticate_can_edit!
    unless @name.can_edit?(current_user)
      flash[:alert] = 'User cannot edit name'
      redirect_to(@name)
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through
  def name_params
    fields = []
    if @name.can_edit_validated?(current_user)
      fields += %i[
        notes ncbi_taxonomy lpsn_url gtdb_accession algaebase_species
        algaebase_taxonomy wikispecies_entry
      ]
      unless @name.type?
        fields += %i[
          nomenclatural_type_type nomenclatural_type_id
          nomenclatural_type_entry
        ]
      end
    end

    if @name.can_edit?(current_user)
      fields += %i[
        name rank description syllabication syllabication_reviewed
        nomenclatural_type_type nomenclatural_type_id nomenclatural_type_entry
        etymology_text register genome_strain
      ] + etymology_pars
    end

    fields << :redirect if current_user.try(:curator?)

    @name_params ||= params.require(:name).permit(*fields.uniq)
  end

  def etymology_pars
    Name.etymology_particles.map do |i|
      Name.etymology_fields.map { |j| :"etymology_#{i}_#{j}" }
    end.flatten
  end

  def change_status(fun, success_msg, *extra_opts)
    if @name.send(fun, *extra_opts)
      flash[:notice] = success_msg
    else
      flash[:alert] = @name.status_alert
    end
    redirect_to(@name)
  rescue ActiveRecord::RecordInvalid => inv
    flash['alert'] =
      'An unexpected error occurred while updating the name: ' +
      inv.record.errors.map { |e| "#{e.attribute} #{e.message}" }.to_sentence
    redirect_to(inv.record)
  end

  def add_automatic_correspondence(message)
    NameCorrespondence.new(
      message: message, notify: '0', automatic: true,
      user: current_user, name: @name
    ).save
  end
end
