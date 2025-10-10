class EphemeralReport
  attr :obj
  attr :messages

  def initialize(obj)
    @obj = obj
    @messages = []
  end

  def <<(message)
    @messages << EphemeralMessage.new(message)
  end

  def error(message)
    @messages << EphemeralMessage.new(message, type: :error)
  end
end

class EphemeralMessage
  attr :message
  attr :timestamp
  attr :type

  def initialize(message, type: :info)
    @message = message
    @timestamp = DateTime.now
    @type = type.to_sym
  end

  def to_s
    @message.is_a?(EphemeralMessage) ?
      @message.to_s :
      '[%s] %s' % [@timestamp.to_s, @message.to_s]
  end
end
