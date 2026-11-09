class ReminderMail < ApplicationRecord
  SMTP_MAX_RETRIES = 5

  # Longest wait for a server-requested retry. Longer blocks (e.g., the
  # provider's daily quota) end the run instead, and it resumes the next day
  SMTP_MAX_WAIT = 15.minutes

  # Reminders sent per run (the task runs daily), leaving room in the SMTP
  # provider's daily quota for regular notifications
  DAILY_LIMIT = 40

  class << self
    ##
    # Remind users with pending registers, at most once a month per user and
    # up to +limit+ users per run, oldest reminders first. Returns the number
    # of reminders sent
    def register_reminder(limit: DAILY_LIMIT)
      sent = 0
      due_users.each do |user|
        break if sent >= limit

        registers = pending_registers(user)
        next if registers.empty? || !user.opt_notification?

        message =
          AdminMailer.with(user: user, registers: registers)
                     .register_reminder_email
        unless deliver_with_retry(message)
          $stderr.puts "Stopped after #{sent} reminders: #{@stop_reason}"
          break
        end

        user.update_column(:register_reminder_at, Time.current)
        sent += 1
        sleep 2 # Stay under the SMTP provider's recipient rate limit
      end
      sent
    end

    private

    def due_users
      User.joins(:registers)
          .where(registers: { notified: false })
          .where(
            'users.register_reminder_at IS NULL OR ' \
            'users.register_reminder_at < ?', 1.month.ago
          )
          .distinct
          .order(Arel.sql('users.register_reminder_at ASC NULLS FIRST'), :id)
    end

    def pending_registers(user)
      user.registers.select do |register|
        !register.validated? && (register.updated_at < 1.month.ago) && (
          !register.submitted? ||
          (!register.notified? && register.all_endorsed?)
        )
      end
    end

    ##
    # Deliver +message+, retrying when the SMTP server temporarily rejects it
    # (421) and asks to wait no longer than +SMTP_MAX_WAIT+. Returns +false+
    # (with the reason in +@stop_reason+) if the server asks to wait longer
    def deliver_with_retry(message)
      attempts = 0
      begin
        message.deliver_now
        true
      rescue Net::SMTPServerBusy => e
        attempts += 1
        raise if attempts > SMTP_MAX_RETRIES

        delay = smtp_retry_delay(e.message)
        if delay > SMTP_MAX_WAIT
          @stop_reason = e.message.strip
          return false
        end

        sleep(delay)
        retry
      end
    end

    ##
    # Seconds to wait before retrying, as requested by the server's
    # "try again after <time>" message (60 if no time is given)
    def smtp_retry_delay(error_message)
      if error_message =~ /try again after (.+?)\s*\z/
        retry_at = Time.parse($1) rescue nil
        return [(retry_at - Time.now).ceil, 1].max if retry_at
      end
      60
    end
  end
end
