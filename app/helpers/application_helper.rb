module ApplicationHelper
  def pager(object)
    will_paginate object,
      renderer: WillPaginate::ActionView::BootstrapLinkRenderer,
      list_classes: %w(pagination justify-content-center)
  end
end
