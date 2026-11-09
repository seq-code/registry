class ReminderMail < ApplicationRecord
  SMTP_MAX_RETRIES = 5

  class << self
    def register_reminder
      users =
        User.joins(:registers)
            .where(registers: { notified: false })
            .distinct!

      users.each do |user|
        registers =
          user.registers.select do |register|
            !register.validated? && (register.updated_at < 1.month.ago) && (
              !register.submitted? ||
              (!register.notified? && register.all_endorsed?)
            )
          end

        unless registers.empty?
          deliver_with_retry(
            AdminMailer.with(user: user, registers: registers)
                       .register_reminder_email
          )
          sleep 2 # Stay under the SMTP provider's recipient rate limit
        end
      end
    end

    private

    # Retry deliveries temporarily rejected by the SMTP server (421),
    # waiting until the time the server asks for
    def deliver_with_retry(message)
      attempts = 0
      begin
        message.deliver_now
      rescue Net::SMTPServerBusy => e
        attempts += 1
        raise if attempts > SMTP_MAX_RETRIES

        sleep(smtp_retry_delay(e.message))
        retry
      end
    end

    def smtp_retry_delay(error_message)
      if error_message =~ /try again after (.+?)\s*\z/
        retry_at = Time.parse($1) rescue nil
        return (retry_at - Time.now).ceil.clamp(1, 900) if retry_at
      end
      60
    end
  end
end
