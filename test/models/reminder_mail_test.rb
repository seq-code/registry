require 'test_helper'
require 'minitest/mock'
require 'net/smtp'

class ReminderMailTest < ActiveSupport::TestCase
  # Test delivery method that rejects the first +failures+ messages with a 421
  # response asking to retry after +retry_in+ seconds
  class BusyDelivery
    class << self
      attr_accessor :failures, :retry_in
    end

    def initialize(_settings); end

    def deliver!(mail)
      if self.class.failures.positive?
        self.class.failures -= 1
        retry_at = (Time.now + self.class.retry_in).utc.strftime('%a, %d %b %Y %H:%M:%S UTC')
        raise Net::SMTPServerBusy.new(Net::SMTP::Response.parse(
          "421 Domain seqco.de is not allowed to send: limit exceeded, try again after #{retry_at}\n"
        ))
      end
      ActionMailer::Base.deliveries << mail
    end
  end
  ActionMailer::Base.add_delivery_method(:busy, BusyDelivery)

  setup do
    ActionMailer::Base.deliveries.clear
    # Every register in the fixtures is a month-old pending register
    Register.update_all(updated_at: 2.months.ago)

    @contributor = users(:contributor)
    @curator = users(:curator)
    registers(:draft).dup.tap do |r|
      r.accession = 'r:draft02'
      r.user = @curator
      r.save!(validate: false)
    end
    Register.update_all(updated_at: 2.months.ago)

    @sleeps = []
  end

  teardown do
    ActionMailer::Base.delivery_method = :test
  end

  def run_reminders(**opts)
    sent = nil
    _out, @err = capture_io do
      ReminderMail.stub(:sleep, ->(s) { @sleeps << s }) do
        sent = ReminderMail.register_reminder(**opts)
      end
    end
    sent
  end

  def recipients
    ActionMailer::Base.deliveries.flat_map(&:to)
  end

  test 'reminds users with pending registers and records when' do
    assert_equal 2, run_reminders

    assert_equal [@contributor.email, @curator.email].sort, recipients.sort
    assert_not_nil @contributor.reload.register_reminder_at
    assert_not_nil @curator.reload.register_reminder_at
  end

  test 'does not remind users again within a month' do
    @contributor.update_column(:register_reminder_at, 1.week.ago)

    assert_equal 1, run_reminders
    assert_equal [@curator.email], recipients
  end

  test 'reminds users again after a month' do
    @contributor.update_column(:register_reminder_at, 5.weeks.ago)
    @curator.update_column(:register_reminder_at, 1.week.ago)

    assert_equal 1, run_reminders
    assert_equal [@contributor.email], recipients
  end

  test 'sends at most the daily limit, users never reminded first' do
    @contributor.update_column(:register_reminder_at, 2.months.ago)

    assert_equal 1, run_reminders(limit: 1)
    assert_equal [@curator.email], recipients

    # The next run picks up where the previous one stopped
    ActionMailer::Base.deliveries.clear
    assert_equal 1, run_reminders(limit: 1)
    assert_equal [@contributor.email], recipients
  end

  test 'skips users who opted out of notifications without counting them' do
    @contributor.update_column(:opt_notification, false)

    assert_equal 1, run_reminders(limit: 1)
    assert_equal [@curator.email], recipients
    assert_nil @contributor.reload.register_reminder_at
  end

  test 'waits and retries when the server asks for a short wait' do
    ActionMailer::Base.delivery_method = :busy
    BusyDelivery.failures = 1
    BusyDelivery.retry_in = 6

    assert_equal 2, run_reminders
    assert_equal 2, recipients.size
    assert(@sleeps.any? { |s| s.between?(5, 7) }, "slept #{@sleeps}")
  end

  test 'stops until the next run when the server asks for a long wait' do
    ActionMailer::Base.delivery_method = :busy
    BusyDelivery.failures = 1
    BusyDelivery.retry_in = 9.hours.to_i

    assert_equal 0, run_reminders
    assert_empty recipients
    assert_nil @contributor.reload.register_reminder_at
    assert_nil @curator.reload.register_reminder_at
    assert_empty @sleeps
    assert_match(/Stopped after 0 reminders: 421 .*limit exceeded/, @err)
  end
end
