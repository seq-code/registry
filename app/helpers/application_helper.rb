module ApplicationHelper
  def pager(object)
    will_paginate object,
      renderer: WillPaginate::ActionView::BootstrapLinkRenderer,
      list_classes: %w(pagination justify-content-center)
  end

  def current_contributor?
    current_user.try :contributor?
  end

  def current_admin?
    current_user.try :admin?
  end
end
