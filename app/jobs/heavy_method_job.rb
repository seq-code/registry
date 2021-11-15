class HeavyMethodJob < ApplicationJob
  queue_as :default

  def perform(method, *objs)
    objs.each(&method)
  end
end
