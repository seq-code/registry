class NotificationsController < ApplicationController
  before_action(:authenticate_user!)
  before_action(:set_notification, only: %i[update show toggle_seen destroy])
  before_action(:authenticate_owner!, only: %i[update show toggle_seen destroy])

  # GET /alerts or /alerts.json
  def index
    @notifications =
      current_user.notifications
        .paginate(page: params[:page], per_page: 50)
  end

  # GET /alerts/1
  def show
    @notification.update(seen: true)
    redirect_to(@notification.linkeable || @notification.notifiable)
  end

  # POST /alerts/1/toggle_seen
  def toggle_seen
    seen = !@notification.seen?
    @notification.update(seen: seen)
    redirect_to(notifications_url)
  end

  # PATCH/PUT /alerts/1
  def update
    if @notification.update(notification_params)
      redirect_to(notifications_url)
    else
      flash[:alert] = 'Cannot update alert'
      render :index, status: :unprocessable_entity
    end
  end

  # DELETE /alerts/1
  # DELETE /alerts/1.json
  def destroy
    @notification.destroy
    respond_to do |format|
      format.html { redirect_to(notifications_url) }
      format.json { head :no_content }
    end
  end

  # POST /alerts/all_seen
  def all_seen
    current_user.unseen_notifications.update(seen: true)
    redirect_to(notifications_url)
  end

  # POST /alerts/all_destroy
  def all_destroy
    current_user.notifications.destroy_all
    redirect_to(notifications_url)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_notification
    @notification = Notification.find(params[:id])
    redirect_to(root_url) if @notification.user != current_user
  end

  # Only allow a list of trusted parameters through.
  def notification_params
    params.require(:notification).permit(*%i[seen])
  end

  def authenticate_owner!
    unless @notification.user == current_user
      flash[:alert] = 'User cannot access notification'
      redirect_to(root_path)
    end
  end

end
