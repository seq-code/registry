class EphemeralReport
  attr :obj
  attr :messages
  attr :report

  def initialize(obj)
    @obj = obj
    @messages = []
    @report = nil
  end

  def <<(message)
    @messages << EphemeralMessage.new(message) if message
  end

  %i[info error warn section].each do |type|
    define_method(type) do |message|
      @messages << EphemeralMessage.new(message, type: type) if message
    end
  end

  def title_message
    EphemeralMessage.new(obj.qualified_id, type: :section)
  end

  def end_message
    EphemeralMessage.new('Report end for %s' % obj.qualified_id)
  end

  def all_messages
    [title_message] + @messages + [end_message]
  end

  def to_s
    all_messages.map(&:to_s).join("\n")
  end

  def to_html
    all_messages.map(&:to_html).join("\n")
  end

  def save
    par = { linkeable: obj, text: to_s, html: to_html }
    if @report
      @report.update(par)
    else
      @report = Report.new(par)
      @report.save
    end
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
    @message.is_a?(EphemeralReport) ?
      @message.to_s :
      '%s: [%s] %s' % [@type.to_s.upcase, @timestamp.to_s, @message.to_s]
  end

  def to_html
    @message.is_a?(EphemeralReport) ?
      @message.to_html :
      '<div class="%s %s"><span class="text-muted">[%s]</span> %s</div>' % [
        'report-message', html_class, @timestamp.to_s, @message.to_s
      ]
  end

  def html_class
    case type
    when :error
      'text-danger'
    when :warn
      'text-alert'
    when :section
      'text-info'
    else
      ''
    end
  end
end
