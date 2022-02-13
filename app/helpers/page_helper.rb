module PageHelper
  def page_url(name)
    send("page_#{name}_url")
  end

  def page_path(name)
    send("page_#{name}_path")
  end
end
